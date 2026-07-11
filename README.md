# Kubernetes Calico CNI Demo - Minikube Edition

## Step 1: Setup Minikube with Calico

```bash
# Delete existing cluster (if any)
minikube delete

# Start Minikube with Calico CNI
minikube start --cni=calico --cpus=2 --memory=4096 --driver=docker

# Verify Calico pods are running
kubectl get pods -n kube-system -l k8s-app=calico-node

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=300s
```

## Step 2: Install calicoctl (Optional but Recommended)

```bash
# Download calicoctl
curl -L https://github.com/projectcalico/calico/releases/download/v3.26.1/calicoctl-linux-amd64 -o calicoctl
chmod +x calicoctl
sudo mv calicoctl /usr/local/bin/

# Verify
calicoctl version
```

## Step 3: Create Project Directory

```bash
mkdir -p ~/calico-demo
cd ~/calico-demo
```

## Step 4: Create Namespace

Create `01-namespace.yaml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: calico-demo
  labels:
    name: calico-demo
```

Apply:
```bash
kubectl apply -f 01-namespace.yaml
```

## Step 5: Deploy Applications

Create `02-deployments.yaml`:
```yaml
# Frontend Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: calico-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
      tier: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: calico-demo
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
---
# Backend Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: calico-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
      tier: backend
  template:
    metadata:
      labels:
        app: backend
        tier: backend
    spec:
      containers:
      - name: backend
        image: hashicorp/http-echo
        args:
        - "-text=Backend API"
        - "-listen=:8080"
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: calico-demo
spec:
  selector:
    app: backend
  ports:
  - port: 8080
    targetPort: 8080
---
# Database Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: calico-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
      tier: database
  template:
    metadata:
      labels:
        app: database
        tier: database
    spec:
      containers:
      - name: redis
        image: redis:alpine
        ports:
        - containerPort: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: database
  namespace: calico-demo
spec:
  selector:
    app: database
  ports:
  - port: 6379
    targetPort: 6379
```

Apply:
```bash
kubectl apply -f 02-deployments.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l tier=frontend -n calico-demo --timeout=120s
kubectl wait --for=condition=ready pod -l tier=backend -n calico-demo --timeout=120s
kubectl wait --for=condition=ready pod -l tier=database -n calico-demo --timeout=120s

# Check status
kubectl get pods -n calico-demo -o wide
```

## Step 6: Test Without Network Policies (Everything Works)

```bash
# Get pod names
FRONTEND_POD=$(kubectl get pod -n calico-demo -l app=frontend -o jsonpath='{.items[0].metadata.name}')
BACKEND_POD=$(kubectl get pod -n calico-demo -l app=backend -o jsonpath='{.items[0].metadata.name}')

# Test: Frontend → Backend (should work)
kubectl exec -n calico-demo $FRONTEND_POD -- wget -qO- --timeout=2 http://backend:8080

# Test: Frontend → Database (should work)
kubectl exec -n calico-demo $FRONTEND_POD -- wget -qO- --timeout=2 http://database:6379 2>&1 || echo "Connected to Redis"

# Test: Backend → Database (should work)
kubectl exec -n calico-demo $BACKEND_POD -- nc -zv database 6379 -w 2
```

## Step 7: Apply Network Policies

Create `03-network-policies.yaml`:
```yaml
# 1. Default Deny All
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: calico-demo
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
# 2. Allow DNS
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: calico-demo
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: UDP
      port: 53
---
# 3. Frontend → Backend (Ingress)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: calico-demo
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
---
# 4. Frontend → Backend (Egress)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-egress-to-backend
  namespace: calico-demo
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 8080
---
# 5. Backend → Database (Ingress)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
  namespace: calico-demo
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 6379
---
# 6. Backend → Database (Egress)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-egress-to-database
  namespace: calico-demo
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 6379
```

Apply:
```bash
kubectl apply -f 03-network-policies.yaml

# Verify policies
kubectl get networkpolicies -n calico-demo
```

## Step 8: Test With Network Policies

```bash
# Get pod names again
FRONTEND_POD=$(kubectl get pod -n calico-demo -l app=frontend -o jsonpath='{.items[0].metadata.name}')
BACKEND_POD=$(kubectl get pod -n calico-demo -l app=backend -o jsonpath='{.items[0].metadata.name}')

echo "=== Test 1: Frontend → Backend (SHOULD WORK) ==="
kubectl exec -n calico-demo $FRONTEND_POD -- wget -qO- --timeout=2 http://backend:8080 && echo "✓ SUCCESS" || echo "✗ FAILED"

echo -e "\n=== Test 2: Frontend → Database (SHOULD FAIL) ==="
kubectl exec -n calico-demo $FRONTEND_POD -- nc -zv database 6379 -w 2 && echo "✗ POLICY NOT WORKING" || echo "✓ BLOCKED AS EXPECTED"

echo -e "\n=== Test 3: Backend → Database (SHOULD WORK) ==="
kubectl exec -n calico-demo $BACKEND_POD -- nc -zv database 6379 -w 2 && echo "✓ SUCCESS" || echo "✗ FAILED"
```

## Step 9: Visualize with Calico

```bash
# View network policies
kubectl describe networkpolicy -n calico-demo

# View Calico workload endpoints
calicoctl get workloadendpoint -n calico-demo

# View IP assignments
kubectl get pods -n calico-demo -o wide

# Check Calico node status
calicoctl node status
```

## Step 10: Advanced - Create Calico NetworkPolicy

Create `04-calico-policy.yaml`:
```yaml
apiVersion: projectcalico.org/v3
kind: NetworkPolicy
metadata:
  name: advanced-frontend-policy
  namespace: calico-demo
spec:
  selector: app == "frontend"
  types:
  - Egress
  egress:
  # Allow to backend
  - action: Allow
    protocol: TCP
    destination:
      selector: app == "backend"
      ports:
      - 8080
  # Allow DNS
  - action: Allow
    protocol: UDP
    destination:
      ports:
      - 53
  # Log and deny everything else
  - action: Log
  - action: Deny
```

Apply:
```bash
kubectl apply -f 04-calico-policy.yaml
```

## Monitoring & Debugging

```bash
# Watch pods
kubectl get pods -n calico-demo -w

# Check logs
kubectl logs -n calico-demo -l app=frontend

# Describe network policy
kubectl describe networkpolicy -n calico-demo

# Check Calico logs
kubectl logs -n kube-system -l k8s-app=calico-node --tail=50

# Get all Calico resources
calicoctl get networkpolicy -A
calicoctl get globalnetworkpolicy
```

## Cleanup

```bash
# Delete namespace (removes all resources)
kubectl delete namespace calico-demo

# Or delete Minikube entirely
minikube delete
```

## Quick Test Script

Create `test.sh`:
```bash
#!/bin/bash

NAMESPACE="calico-demo"
FRONTEND_POD=$(kubectl get pod -n $NAMESPACE -l app=frontend -o jsonpath='{.items[0].metadata.name}')
BACKEND_POD=$(kubectl get pod -n $NAMESPACE -l app=backend -o jsonpath='{.items[0].metadata.name}')

echo "========================================="
echo "Network Policy Test Results"
echo "========================================="

echo -e "\n✓ Test 1: Frontend → Backend (Allowed)"
kubectl exec -n $NAMESPACE $FRONTEND_POD -- wget -qO- --timeout=2 http://backend:8080 2>/dev/null && echo "PASS" || echo "FAIL"

echo -e "\n✗ Test 2: Frontend → Database (Blocked)"
kubectl exec -n $NAMESPACE $FRONTEND_POD -- nc -zv database 6379 -w 2 2>&1 | grep -q "succeeded" && echo "FAIL - Should be blocked!" || echo "PASS - Blocked as expected"

echo -e "\n✓ Test 3: Backend → Database (Allowed)"
kubectl exec -n $NAMESPACE $BACKEND_POD -- nc -zv database 6379 -w 2 2>&1 | grep -q "succeeded" && echo "PASS" || echo "FAIL"

echo -e "\n========================================="
```

Make executable and run:
```bash
chmod +x test.sh
./test.sh
```

## Troubleshooting

### Issue: Pods not starting
```bash
kubectl describe pod -n calico-demo
kubectl logs -n kube-system -l k8s-app=calico-node
```

### Issue: Network policies not working
```bash
# Check if Calico is running
kubectl get pods -n kube-system | grep calico

# Verify policy syntax
kubectl get networkpolicy -n calico-demo -o yaml
```

### Issue: Cannot connect to Minikube
```bash
minikube status
minikube start
kubectl cluster-info
```
# for more info please checkout the .md file named
Kubernetes Calico CNI Demo Project.md

### Remove Kubernetes cluster where Using calico

# Delete Calico via manifest (if installed this way)
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

# OR if installed via Tigera operator
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml
kubectl delete installation default

# OR if installed via Helm
helm uninstall calico -n tigera-operator


### Clean up leftover Calico resources

kubectl delete crd -l app.kubernetes.io/name=calico --ignore-not-found
kubectl get crd | grep -i calico | awk '{print $1}' | xargs kubectl delete crd
kubectl delete namespace calico-system calico-apiserver tigera-operator --ignore-not-found
.......................
sudo ip link delete cali0 2>/dev/null
sudo ip link delete tunl0 2>/dev/null
sudo ip link delete vxlan.calico 2>/dev/null
sudo rm -rf /etc/cni/net.d/10-calico.conflist
sudo rm -rf /etc/cni/net.d/calico-kubeconfig
sudo rm -rf /var/lib/calico
### Part 2: Fully Delete the Entire Kubernetes Cluster

kubectl drain <node-name> --delete-emptydir-data --force --ignore-daemonsets
kubectl delete node <node-name>

### Step 2 — On every node (master + workers): reset kubeadm

sudo kubeadm reset -f
## Step 3 — Clean up remaining files/directories on every node
sudo rm -rf /etc/cni/net.d
sudo rm -rf /etc/kubernetes
sudo rm -rf /var/lib/etcd
sudo rm -rf /var/lib/kubelet
sudo rm -rf $HOME/.kube
sudo rm -rf /var/lib/cni/
sudo rm -rf /opt/cni/bin
### Step 4 — Clean up iptables rules (created by kube-proxy/Calico)
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X

sudo ipvsadm --clear 2>/dev/null   # if using IPVS mode

### Step 5 — Remove leftover network interfaces

sudo ip link delete cni0 2>/dev/null
sudo ip link delete flannel.1 2>/dev/null
sudo ip link delete cali0 2>/dev/null
sudo ip link delete tunl0 2>/dev/null
sudo ip link delete vxlan.calico 2>/dev/null
sudo ip link delete kube-ipvs0 2>/dev/null
### Step 6 — (Optional) Uninstall packages entirely


sudo apt-get purge -y kubeadm kubectl kubelet kubernetes-cni
sudo apt-get autoremove -y


### Step 7 — Reboot nodes (recommended)
sudo reboot



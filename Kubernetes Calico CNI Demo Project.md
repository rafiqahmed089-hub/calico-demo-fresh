# Kubernetes Calico CNI Demo Project

This project demonstrates Calico CNI features including network policies, pod networking, and security controls.

## Prerequisites

- Kubernetes cluster (v1.20+)
- kubectl configured
- Calico CNI installed

## Project Structure

```
calico-demo/
├── 01-namespace.yaml
├── 02-frontend-deployment.yaml
├── 03-backend-deployment.yaml
├── 04-database-deployment.yaml
├── 05-network-policies.yaml
└── README.md
```

## Step 1: Install Calico CNI

```bash
# Install Calico operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml

# Install Calico custom resources
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml

# Verify installation
watch kubectl get pods -n calico-system
```

## Step 2: Create Namespace

**01-namespace.yaml**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: calico-demo
  labels:
    name: calico-demo
```

```bash
kubectl apply -f 01-namespace.yaml
```

## Step 3: Deploy Frontend Application

**02-frontend-deployment.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: calico-demo
  labels:
    app: frontend
    tier: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: calico-demo
spec:
  selector:
    app: frontend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
```

```bash
kubectl apply -f 02-frontend-deployment.yaml
```

## Step 4: Deploy Backend Application

**03-backend-deployment.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: calico-demo
  labels:
    app: backend
    tier: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
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
        - "-text=Backend API Response"
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: calico-demo
spec:
  selector:
    app: backend
  ports:
  - protocol: TCP
    port: 5678
    targetPort: 5678
  type: ClusterIP
```

```bash
kubectl apply -f 03-backend-deployment.yaml
```

## Step 5: Deploy Database

**04-database-deployment.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: calico-demo
  labels:
    app: database
    tier: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
        tier: database
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_PASSWORD
          value: "demopassword"
        ports:
        - containerPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: database-service
  namespace: calico-demo
spec:
  selector:
    app: database
  ports:
  - protocol: TCP
    port: 5432
    targetPort: 5432
  type: ClusterIP
```

```bash
kubectl apply -f 04-database-deployment.yaml
```

## Step 6: Apply Calico Network Policies

**05-network-policies.yaml**
```yaml
# Default Deny All Traffic
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
# Allow Frontend to Backend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-to-backend
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
      port: 5678
---
# Allow Backend to Database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-to-database
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
      port: 5432
---
# Allow DNS for all pods
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
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
---
# Allow Backend Egress to Database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-egress
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
      port: 5432
---
# Allow Frontend Egress to Backend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-egress
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
      port: 5678
---
# Calico GlobalNetworkPolicy (requires Calico API)
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: deny-external-egress
spec:
  selector: has(tier)
  types:
  - Egress
  egress:
  - action: Allow
    destination:
      nets:
      - 10.0.0.0/8
      - 172.16.0.0/12
      - 192.168.0.0/16
  - action: Deny
    destination:
      nets:
      - 0.0.0.0/0
```

```bash
kubectl apply -f 05-network-policies.yaml
```

## Step 7: Testing Network Policies

### Test 1: Frontend can reach Backend
```bash
# Get frontend pod name
FRONTEND_POD=$(kubectl get pod -n calico-demo -l app=frontend -o jsonpath='{.items[0].metadata.name}')

# Test connection to backend
kubectl exec -n calico-demo $FRONTEND_POD -- curl -s backend-service:5678
# Expected: Success - "Backend API Response"
```

### Test 2: Frontend cannot reach Database (blocked)
```bash
# Try to connect to database from frontend
kubectl exec -n calico-demo $FRONTEND_POD -- nc -zv database-service 5432 -w 2
# Expected: Timeout/Failure
```

### Test 3: Backend can reach Database
```bash
# Get backend pod name
BACKEND_POD=$(kubectl get pod -n calico-demo -l app=backend -o jsonpath='{.items[0].metadata.name}')

# Test connection to database
kubectl exec -n calico-demo $BACKEND_POD -- nc -zv database-service 5432 -w 2
# Expected: Success
```

## Step 8: Monitor with Calico

### View Network Policies
```bash
# List network policies
kubectl get networkpolicies -n calico-demo

# View Calico network policies
calicoctl get networkpolicy -n calico-demo -o wide
```

### Check Pod IP Addresses
```bash
kubectl get pods -n calico-demo -o wide
```

### View Calico Endpoints
```bash
calicoctl get workloadendpoint -n calico-demo
```

### Check IP Pool
```bash
calicoctl get ippool -o wide
```

## Step 9: Advanced Calico Features

### Create IP Pool
```yaml
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: demo-pool
spec:
  cidr: 192.168.0.0/16
  ipipMode: Always
  natOutgoing: true
```

### Enable Flow Logs (for monitoring)
```bash
kubectl annotate namespace calico-demo projectcalico.org/flowlogs=enabled
```

## Cleanup

```bash
# Delete all resources
kubectl delete namespace calico-demo

# Remove Calico (if needed)
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│           Calico CNI Network Layer              │
└─────────────────────────────────────────────────┘
                      │
      ┌───────────────┼───────────────┐
      │               │               │
┌─────▼─────┐   ┌────▼────┐   ┌──────▼──────┐
│ Frontend  │   │ Backend │   │  Database   │
│  (nginx)  │──▶│ (API)   │──▶│ (postgres)  │
│  Tier: 1  │   │ Tier: 2 │   │  Tier: 3    │
└───────────┘   └─────────┘   └─────────────┘
     ✓               ✓               ✓
  Allowed        Allowed         Blocked
  Frontend→      Backend→        Frontend→
  Backend        Database        Database
```

## Key Features Demonstrated

1. **Network Segmentation**: Three-tier application with isolated network layers
2. **Default Deny**: All traffic blocked by default
3. **Selective Allow**: Only necessary connections permitted
4. **Egress Control**: Outbound traffic restrictions
5. **DNS Access**: Pods can resolve DNS queries
6. **Global Policies**: Cluster-wide network rules

## Troubleshooting

### Check Calico Status
```bash
kubectl get pods -n calico-system
calicoctl node status
```

### View Logs
```bash
kubectl logs -n calico-system -l k8s-app=calico-node
```

### Debug Network Policy
```bash
# Check if policy is applied
kubectl describe networkpolicy -n calico-demo

# Check pod labels
kubectl get pods -n calico-demo --show-labels
```

## Additional Resources

- [Calico Documentation](https://docs.projectcalico.org/)
- [Network Policy Tutorial](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Calico GitHub](https://github.com/projectcalico/calico)
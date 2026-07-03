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

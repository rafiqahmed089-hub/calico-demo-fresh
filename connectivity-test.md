# Get pod names
FRONTEND_POD=$(kubectl get pod -n calico-demo -l app=frontend -o jsonpath='{.items[0].metadata.name}')
BACKEND_POD=$(kubectl get pod -n calico-demo -l app=backend -o jsonpath='{.items[0].metadata.name}')

echo "=== Testing connectivity BEFORE network policies ==="
echo ""
echo "1. Frontend -> Backend (should work):"
kubectl exec -n calico-demo $FRONTEND_POD -- wget -qO- --timeout=2 http://backend:8080
echo ""

echo "2. Frontend -> Database (should work):"
kubectl exec -n calico-demo $FRONTEND_POD -- nc -zv database 6379 -w 2
echo ""

echo "3. Backend -> Database (should work):"
kubectl exec -n calico-demo $BACKEND_POD -- nc -zv database 6379 -w 2

# Get pod names
FRONTEND_POD=$(kubectl get pod -n calico-demo -l app=frontend -o jsonpath='{.items[0].metadata.name}')

echo ""
echo "=== Testing connectivity AFTER network policies ==="
echo ""

echo "✓ Test 1: Frontend -> Backend (SHOULD WORK):"
kubectl exec -n calico-demo $FRONTEND_POD -- wget -qO- --timeout=2 http://backend:8080 && echo "✓ SUCCESS" || echo "✗ FAILED"
echo ""

echo "✗ Test 2: Frontend -> Database (SHOULD BE BLOCKED):"
kubectl exec -n calico-demo $FRONTEND_POD -- timeout 3 nc -zv database 6379 2>&1
if [ $? -eq 0 ]; then
    echo "✗ FAILED - Connection should be blocked!"
else
    echo "✓ SUCCESS - Connection blocked as expected"
fi
echo ""

echo "=== Network Policy Summary ==="
kubectl describe networkpolicy -n calico-demo | grep -E "Name:|Spec:|Allowing|PodSelector"

cat > test-policies.sh <<'EOF'
#!/bin/bash

NAMESPACE="calico-demo"
FRONTEND_POD=$(kubectl get pod -n $NAMESPACE -l app=frontend -o jsonpath='{.items[0].metadata.name}')

echo "========================================="
echo "   Calico Network Policy Verification"
echo "========================================="
echo ""

echo "Test 1: Frontend → Backend (Allowed)"
echo "-------------------------------------"
if kubectl exec -n $NAMESPACE $FRONTEND_POD -- wget -qO- --timeout=2 http://backend:8080 2>/dev/null; then
    echo "✓ PASS - Connection successful"
else
    echo "✗ FAIL - Connection blocked"
fi
echo ""

echo "Test 2: Frontend → Database (Blocked)"
echo "--------------------------------------"
# Use timeout and check exit code
kubectl exec -n $NAMESPACE $FRONTEND_POD -- timeout 3 sh -c 'cat < /dev/null > /dev/tcp/database/6379' 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✗ FAIL - Connection allowed (policy not working!)"
else
    echo "✓ PASS - Connection blocked as expected"
fi
echo ""

echo "========================================="
echo "Active Network Policies:"
kubectl get networkpolicies -n $NAMESPACE --no-headers | awk '{print "  - " $1}'
echo ""
echo "Total Pods:"
kubectl get pods -n $NAMESPACE --no-headers | wc -l
echo "========================================="
EOF

chmod +x test-policies.sh
./test-policies.sh

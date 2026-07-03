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

echo -e "

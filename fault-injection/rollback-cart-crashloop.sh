#!/bin/bash
# Cart CrashLoopBackOff Rollback Script
# Removes the SPRING_APPLICATION_JSON env var injected during fault injection

set -e

NAMESPACE="carts"
DEPLOYMENT="carts"

echo "=== Cart CrashLoopBackOff Rollback ==="
echo ""

# Remove SPRING_APPLICATION_JSON using a JSON patch to delete the env entry
echo "[1/2] Removing injected SPRING_APPLICATION_JSON env var..."
kubectl patch deployment $DEPLOYMENT -n $NAMESPACE --type=json -p='[
  {
    "op": "remove",
    "path": "/spec/template/spec/containers/0/env"
  }
]' 2>/dev/null || \
kubectl set env deployment/$DEPLOYMENT -n $NAMESPACE SPRING_APPLICATION_JSON-

echo ""
echo "[2/2] Waiting for deployment rollout..."
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=120s

echo ""
kubectl get pods -n $NAMESPACE

echo ""
echo "=== Rollback Complete ==="
echo ""
echo "SPRING_APPLICATION_JSON removed — carts starting with original config."
echo "CrashLoopBackOff alert will resolve once AMP scrapes clean metrics (~2-5 min)."

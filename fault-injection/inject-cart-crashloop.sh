#!/bin/bash
# Cart CrashLoopBackOff Injection Script
# Injects an invalid Spring Boot config via SPRING_APPLICATION_JSON causing
# the app to fail during property binding on startup — mimics a real
# production misconfiguration (e.g. wrong env var value in a ConfigMap).
#
# Spring Boot exits with:
#   IllegalStateException: Failed to bind properties under 'server.port' to int

set -e

NAMESPACE="carts"
DEPLOYMENT="carts"

echo "=== Cart CrashLoopBackOff Injection ==="
echo "Target: $DEPLOYMENT in namespace $NAMESPACE"
echo ""

# Inject an invalid Spring Boot config via SPRING_APPLICATION_JSON.
# Setting server.port to a non-numeric value causes Spring Boot to fail
# during property binding with an IllegalStateException — exactly as a
# misconfigured environment variable would in production.
echo "[1/2] Injecting invalid Spring Boot config (bad server.port value)..."
kubectl patch deployment $DEPLOYMENT -n $NAMESPACE --patch '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "carts",
          "env": [{
            "name": "SPRING_APPLICATION_JSON",
            "value": "{\"server.port\":\"not-a-valid-port\"}"
          }]
        }]
      }
    }
  }
}'

echo ""
echo "[2/2] Waiting for new pods to start failing..."
sleep 10
kubectl get pods -n $NAMESPACE

echo ""
echo "=== CrashLoopBackOff Injection Active ==="
echo ""
echo "Spring Boot will fail with:"
echo "  IllegalStateException: Failed to bind properties under 'server.port' to int"
echo "  (caused by: invalid value 'not-a-valid-port' in SPRING_APPLICATION_JSON)"
echo ""
echo "Grafana alert fires after >2 restarts in 5 min (sustained 1 min)."
echo "Expect DevOps Agent investigation in ~2 minutes."
echo ""
echo "Monitor pods:"
echo "  kubectl get pods -n $NAMESPACE -w"
echo ""
echo "View crash logs:"
echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=carts --previous"
echo ""
echo "Rollback:"
echo "  ./rollback-cart-crashloop.sh"

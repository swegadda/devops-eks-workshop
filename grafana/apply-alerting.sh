#!/usr/bin/env bash
# Apply Grafana alerting configuration (contact point, template, notification policy, alert rules)
# Usage: GRAFANA_URL=http://localhost:3000 GRAFANA_USER=admin GRAFANA_PASS=secret BEARER_TOKEN=<token> ./apply-alerting.sh

set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin}"
BEARER_TOKEN="${BEARER_TOKEN:-}"
FOLDER_UID="${FOLDER_UID:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

grafana_curl() {
  curl -sf -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
    -H "Content-Type: application/json" \
    "$@"
}

echo "==> Ensuring EKS Alerts folder exists..."
FOLDER_RESP=$(grafana_curl -X POST "${GRAFANA_URL}/api/folders" \
  -d '{"title":"EKS Alerts"}' 2>/dev/null || \
  grafana_curl "${GRAFANA_URL}/api/folders" | python3 -c "import json,sys; [print(json.dumps(f)) for f in json.load(sys.stdin) if f['title']=='EKS Alerts']" | head -1)
FOLDER_UID=$(echo "${FOLDER_RESP}" | python3 -c "import json,sys; print(json.load(sys.stdin)['uid'])" 2>/dev/null || echo "${FOLDER_UID}")
echo "    Folder UID: ${FOLDER_UID}"

echo "==> Applying notification template..."
grafana_curl -X PUT "${GRAFANA_URL}/api/v1/provisioning/templates/devops-agent-payload" \
  -d @"${SCRIPT_DIR}/notification-template.json"
echo ""

echo "==> Applying contact point..."
CP_PAYLOAD=$(python3 -c "
import json, sys, os
with open('${SCRIPT_DIR}/contact-point.json') as f:
    cp = json.load(f)
cp['settings']['authorization_credentials'] = os.environ.get('BEARER_TOKEN','${BEARER_TOKEN}')
print(json.dumps(cp))
")
grafana_curl -X POST "${GRAFANA_URL}/api/v1/provisioning/contact-points" \
  -d "${CP_PAYLOAD}" || \
grafana_curl -X PUT "${GRAFANA_URL}/api/v1/provisioning/contact-points" \
  -d "${CP_PAYLOAD}"
echo ""

echo "==> Applying notification policy..."
grafana_curl -X PUT "${GRAFANA_URL}/api/v1/provisioning/policies" \
  -d @"${SCRIPT_DIR}/notification-policy.json"
echo ""

echo "==> Applying alert rules..."
for rule_file in "${SCRIPT_DIR}/alerts/"*.json; do
  RULE=$(python3 -c "
import json, sys
with open('${rule_file}') as f:
    r = json.load(f)
r['folderUID'] = '${FOLDER_UID}'
print(json.dumps(r))
")
  grafana_curl -X POST "${GRAFANA_URL}/api/v1/provisioning/alert-rules" \
    -d "${RULE}"
  echo "    Applied: $(basename ${rule_file})"
done

echo ""
echo "Done. All alerting configurations applied."

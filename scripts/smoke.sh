#!/bin/bash
set -euo pipefail

# Smoke test: show vm-novatrix-web + public IP, then curl the web server.
# Usage: ./scripts/smoke.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

# Load .env if present (plain KEY=VALUE lines)
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

: "${AZ_SUBSCRIPTION_ID:?"Error: AZ_SUBSCRIPTION_ID not set. Add it to .env or export it."}"
: "${AZ_RESOURCE_GROUP:=rg-novatrix}"

if ! az account show &>/dev/null; then
  echo "Error: not logged into Azure CLI. Run: az login" >&2
  exit 1
fi

az account set --subscription "$AZ_SUBSCRIPTION_ID"

echo "=== vm-novatrix-web ==="
az vm show --resource-group "$AZ_RESOURCE_GROUP" --name vm-novatrix-web \
  --query "{name:name, provisioningState:provisioningState, vmSize:hardwareProfile.vmSize, os:storageProfile.imageReference.offer}" \
  -o table

POWER_STATE="$(az vm get-instance-view --resource-group "$AZ_RESOURCE_GROUP" --name vm-novatrix-web \
  --query "instanceView.statuses[?code=='PowerState/running'].displayStatus" -o tsv)"
echo "Power state: ${POWER_STATE:-not running}"

PIP="$(az network public-ip show --resource-group "$AZ_RESOURCE_GROUP" --name pip-novatrix-web --query ipAddress -o tsv)"
echo "Public IP: $PIP"

echo "=== HTTP check ==="
BODY="$(mktemp)"
HTTP="$(curl -sS -m 10 -o "$BODY" -w '%{http_code}' "http://$PIP/" || true)"
if [ "$HTTP" != "200" ]; then
  echo "FAIL: expected HTTP 200 from http://$PIP/, got ${HTTP:-curl-error}" >&2
  rm -f "$BODY"
  exit 1
fi
if ! grep -q "Novatrix" "$BODY"; then
  echo "FAIL: HTTP 200 but response missing Novatrix marker" >&2
  rm -f "$BODY"
  exit 1
fi
rm -f "$BODY"
echo "HTTP 200 + Novatrix marker OK"
echo "Smoke check done."
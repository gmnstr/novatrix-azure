#!/bin/bash
set -euo pipefail

# Bootstrap the Novatrix course environment.
# - loads .env (AZ_SUBSCRIPTION_ID required)
# - creates rg-novatrix if missing
# - registers required resource providers (idempotent)
# Usage: ./scripts/bootstrap.sh

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

: "${AZ_SUBSCRIPTION_ID:?"Error: AZ_SUBSCRIPTION_ID not set. Add it to .env (e.g. AZ_SUBSCRIPTION_ID=00000000-0000-0000-0000-000000000000) or export it."}"
: "${AZ_RESOURCE_GROUP:=rg-novatrix}"
: "${LOCATION:=swedencentral}"

echo "Novatrix bootstrap"
echo "  Subscription: $AZ_SUBSCRIPTION_ID"
echo "  Resource group: $AZ_RESOURCE_GROUP ($LOCATION)"

if ! command -v az &>/dev/null; then
  echo "Error: Azure CLI not installed" >&2
  exit 1
fi

if ! az account show &>/dev/null; then
  echo "Not logged in. Running az login..."
  az login --use-device-code
fi

az account set --subscription "$AZ_SUBSCRIPTION_ID"

CURRENT_SUB="$(az account show --query id -o tsv)"
if [ "$CURRENT_SUB" != "$AZ_SUBSCRIPTION_ID" ]; then
  echo "Error: could not set subscription (expected $AZ_SUBSCRIPTION_ID, got $CURRENT_SUB)" >&2
  exit 1
fi

if az group show --name "$AZ_RESOURCE_GROUP" &>/dev/null; then
  echo "Resource group $AZ_RESOURCE_GROUP already exists"
else
  echo "Creating resource group $AZ_RESOURCE_GROUP..."
  az group create --name "$AZ_RESOURCE_GROUP" --location "$LOCATION" \
    --tags Application=Novatrix Environment=Course ManagedBy=Bicep
fi

echo "Registering resource providers..."
for provider in Microsoft.Network Microsoft.Compute Microsoft.Storage Microsoft.ManagedIdentity Microsoft.Authorization; do
  az provider register --namespace "$provider" --wait
done

echo "Bootstrap complete."
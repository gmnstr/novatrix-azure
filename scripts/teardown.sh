#!/bin/bash
set -euo pipefail

# Delete the Novatrix resource group (rg-novatrix). Requires confirmation unless --force.
# Usage: ./scripts/teardown.sh [--force|-f]

FORCE=""
for arg in "$@"; do
  case "$arg" in
    --force|-f) FORCE="--force" ;;
    *)
      echo "Error: unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

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

if ! az group show --name "$AZ_RESOURCE_GROUP" &>/dev/null; then
  echo "Resource group $AZ_RESOURCE_GROUP not found; nothing to delete."
  exit 0
fi

echo "WARNING: this permanently deletes resource group $AZ_RESOURCE_GROUP and ALL resources in it."
if [ "$FORCE" != "--force" ]; then
  read -r -p "Type 'DELETE' to confirm: " confirmation
  if [ "$confirmation" != "DELETE" ]; then
    echo "Teardown cancelled."
    exit 0
  fi
fi

az group delete --name "$AZ_RESOURCE_GROUP" --yes --no-wait
echo "Resource group deletion initiated: $AZ_RESOURCE_GROUP"
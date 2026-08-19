#!/bin/bash
set -euo pipefail

# Deploy the Novatrix course environment.
# Usage: ./scripts/deploy.sh [--what-if|-w] [--confirm|-y]
#   --what-if / -w  run what-if analysis, then prompt before deploying
#   --confirm / -y  skip the what-if confirmation prompt
# Prefers the compiled ARM template (build/main.json) when present.
# Refuses to deploy without a compiled build when WEEK >= 38.

WHAT_IF=""
CONFIRM=""
ALLOW_WORLD_SSH=""
for arg in "$@"; do
  case "$arg" in
    --what-if|-w) WHAT_IF="--what-if" ;;
    --confirm|-y) CONFIRM="--confirm" ;;
    --allow-world-ssh) ALLOW_WORLD_SSH="1" ;;
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
: "${WEEK:=0}"

PARAMETERS_FILE="$ROOT_DIR/envs/novatrix.parameters.json"
MAIN_TEMPLATE="$ROOT_DIR/infra/main.bicep"
BUILD_FILE="$ROOT_DIR/build/main.json"

if [ ! -f "$PARAMETERS_FILE" ]; then
  echo "Error: parameters file not found: $PARAMETERS_FILE" >&2
  exit 1
fi

SSH_KEY="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["parameters"]["adminSshPublicKey"]["value"])' "$PARAMETERS_FILE")"
if [[ ! "$SSH_KEY" =~ ^ssh-rsa\ AAAA[A-Za-z0-9+/]+=*(\ .*)?$ ]] || [[ "$SSH_KEY" == *placeholder* ]] || [[ "$SSH_KEY" == REPLACE_WITH* ]]; then
  echo "Error: adminSshPublicKey is missing or invalid (Azure Linux VMs require ssh-rsa)." >&2
  echo "Generate: ssh-keygen -t rsa -b 4096 -f ~/.ssh/novatrix -N ''" >&2
  echo "Then put the contents of ~/.ssh/novatrix.pub into envs/novatrix.parameters.json" >&2
  exit 1
fi

SSH_CIDR="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["parameters"]["allowedSshCidr"]["value"])' "$PARAMETERS_FILE")"
if [ "$SSH_CIDR" = "0.0.0.0/0" ] && [ "$ALLOW_WORLD_SSH" != "1" ]; then
  echo "Error: allowedSshCidr is 0.0.0.0/0. Set your public IP /32, or pass --allow-world-ssh." >&2
  exit 1
fi

# Choose template: compiled ARM when available, else source Bicep.
if [ -f "$BUILD_FILE" ]; then
  TEMPLATE_FILE="$BUILD_FILE"
  echo "Using compiled ARM template: build/main.json"
elif [[ "$WEEK" =~ ^[0-9]+$ ]] && [ "$WEEK" -ge 38 ]; then
  echo "Error: build/main.json missing and WEEK=$WEEK (>= 38) requires a compiled build." >&2
  echo "Run: ./scripts/bicep-build.sh" >&2
  exit 1
else
  TEMPLATE_FILE="$MAIN_TEMPLATE"
  echo "Warning: build/main.json missing; deploying source Bicep. Run ./scripts/bicep-build.sh first for the compiled template."
fi

if ! az account show &>/dev/null; then
  echo "Error: not logged into Azure CLI. Run: az login" >&2
  exit 1
fi

az account set --subscription "$AZ_SUBSCRIPTION_ID"

if ! az group show --name "$AZ_RESOURCE_GROUP" &>/dev/null; then
  echo "Error: resource group $AZ_RESOURCE_GROUP not found. Run: ./scripts/bootstrap.sh" >&2
  exit 1
fi

DEPLOYMENT_NAME="novatrix-$(date +%Y%m%d-%H%M%S)"

if [ "$WHAT_IF" = "--what-if" ]; then
  echo "Running what-if analysis..."
  az deployment group what-if \
    --resource-group "$AZ_RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --template-file "$TEMPLATE_FILE" \
    --parameters "@$PARAMETERS_FILE" \
    --result-format FullResourcePayloads

  if [ "$CONFIRM" != "--confirm" ]; then
    read -r -p "Proceed with deployment? (y/N): " -n 1 reply
    echo
    if [[ ! "$reply" =~ ^[Yy]$ ]]; then
      echo "Deployment cancelled."
      exit 0
    fi
  fi
fi

echo "Deploying $TEMPLATE_FILE to $AZ_RESOURCE_GROUP..."
ATTEMPT=1
MAX_ATTEMPTS=3
until az deployment group create \
  --resource-group "$AZ_RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --template-file "$TEMPLATE_FILE" \
  --parameters "@$PARAMETERS_FILE"; do
  if [ "$ATTEMPT" -ge "$MAX_ATTEMPTS" ]; then
    echo "Error: deployment failed after $MAX_ATTEMPTS attempts." >&2
    exit 1
  fi
  echo "Deployment attempt $ATTEMPT failed (often MI role-assignment replication). Retrying in 30s..."
  ATTEMPT=$((ATTEMPT + 1))
  sleep 30
done

echo "Deployment complete: $DEPLOYMENT_NAME"
#!/bin/bash
set -euo pipefail

# Novatrix Entra support demo: create users + support group, grant least-privilege
# Reader on rg-novatrix to the support group. Never grants Owner.
# Idempotent where possible (existing users/groups/assignments are reused).
# Usage: ./scripts/identity.sh [entra-domain]
#   entra-domain: e.g. studentdomain.com (or set NOVATRIX_ENTRA_DOMAIN in .env)

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

DOMAIN="${1:-${NOVATRIX_ENTRA_DOMAIN:-}}"
GROUP_NAME="${NOVATRIX_SUPPORT_GROUP:-Novatrix Support}"
MAIL_NICKNAME="${NOVATRIX_SUPPORT_MAIL_NICKNAME:-novatrix-support}"
SUPPORT_USERS="${NOVATRIX_SUPPORT_USERS:-novatrix.support1 novatrix.support2}"
PASSWORD="${NOVATRIX_DEMO_PASSWORD:-}"

if [ -z "$DOMAIN" ]; then
  echo "Error: Entra domain required. Pass it as an argument or set NOVATRIX_ENTRA_DOMAIN in .env" >&2
  exit 1
fi

if ! az account show &>/dev/null; then
  echo "Not logged in. Running az login..."
  az login --use-device-code
fi

az account set --subscription "$AZ_SUBSCRIPTION_ID"

RG_SCOPE="/subscriptions/$AZ_SUBSCRIPTION_ID/resourceGroups/$AZ_RESOURCE_GROUP"

# Group (create if missing)
GROUP_ID="$(az ad group list --filter "displayName eq '$GROUP_NAME'" --query "[0].id" -o tsv)"
if [ -z "$GROUP_ID" ]; then
  echo "Creating group: $GROUP_NAME"
  GROUP_ID="$(az ad group create --display-name "$GROUP_NAME" --mail-nickname "$MAIL_NICKNAME" --query id -o tsv)"
  echo "Waiting 20s for Entra group replication before RBAC..."
  sleep 20
else
  echo "Group already exists: $GROUP_NAME"
fi

# Users (create if missing, add to group)
if [ -z "$PASSWORD" ]; then
  PASSWORD="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16 || true)"
  GENERATED_PASSWORD=1
fi

for user in $SUPPORT_USERS; do
  upn="$user@$DOMAIN"
  USER_ID="$(az ad user show --id "$upn" --query id -o tsv 2>/dev/null || true)"
  if [ -z "$USER_ID" ]; then
    echo "Creating user: $upn"
    USER_ID="$(az ad user create \
      --display-name "$user" \
      --user-principal-name "$upn" \
      --password "$PASSWORD" \
      --force-change-password-next-sign-in true \
      --query id -o tsv)"
    echo "  Temporary password set for $upn (must change at first sign-in)"
  else
    echo "User already exists: $upn"
  fi

  if ! az ad group member check --group "$GROUP_ID" --member-id "$USER_ID" --query value -o tsv | grep -qi true; then
    az ad group member add --group "$GROUP_ID" --member-id "$USER_ID"
    echo "  Added to group $GROUP_NAME"
  fi
done

# Least-privilege Reader on the resource group (never Owner)
EXISTING="$(az role assignment list --assignee-object-id "$GROUP_ID" --role Reader --scope "$RG_SCOPE" --query "length(@)" -o tsv)"
if [ -z "$EXISTING" ] || [ "$EXISTING" = "0" ]; then
  echo "Assigning Reader on $RG_SCOPE to group $GROUP_NAME"
  ATTEMPT=1
  until az role assignment create \
    --assignee-object-id "$GROUP_ID" \
    --assignee-principal-type Group \
    --role Reader \
    --scope "$RG_SCOPE"; do
    if [ "$ATTEMPT" -ge 3 ]; then
      echo "Error: Reader assignment failed after 3 attempts." >&2
      exit 1
    fi
    echo "PrincipalNotFound/replication — retry $ATTEMPT in 20s..."
    ATTEMPT=$((ATTEMPT + 1))
    sleep 20
  done
else
  echo "Reader already assigned to $GROUP_NAME on $RG_SCOPE"
fi

if [ "${GENERATED_PASSWORD:-0}" = "1" ]; then
  echo ""
  echo "Generated demo password (shown once): $PASSWORD"
  echo "Set NOVATRIX_DEMO_PASSWORD in .env to reuse a known password."
fi

echo "Done. No Owner role is granted to the support group."
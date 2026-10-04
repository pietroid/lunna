#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ENV_FILE="$SCRIPT_DIR/env/dev.json"
ENV_FILE="$DEFAULT_ENV_FILE"
PROJECT_ID=""
BACKEND_ACCOUNT_NAME=""

# Parse arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    --env-file)
      ENV_FILE="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [--env-file <path>] [PROJECT_ID] [BACKEND_ACCOUNT_NAME]"
      echo ""
      echo "If PROJECT_ID and BACKEND_ACCOUNT_NAME are not provided, they are read"
      echo "from the env file. Defaults:"
      echo "  Env file: $DEFAULT_ENV_FILE"
      echo ""
      echo "Examples:"
      echo "  $0"
  echo "  $0 focus-local-dev focus-backend"
      echo "  $0 --env-file env/production.json"
      exit 0
      ;;
    *)
      if [ -z "$PROJECT_ID" ]; then
        PROJECT_ID="$1"
      elif [ -z "$BACKEND_ACCOUNT_NAME" ]; then
        BACKEND_ACCOUNT_NAME="$1"
      else
        echo "Unknown argument: $1"
        echo "Run '$0 --help' for usage."
        exit 1
      fi
      shift
      ;;
  esac
done

# Try to read missing values from the env file
if [ -f "$ENV_FILE" ] && { [ -z "$PROJECT_ID" ] || [ -z "$BACKEND_ACCOUNT_NAME" ]; }; then
  if command -v jq >/dev/null 2>&1; then
    if [ -z "$PROJECT_ID" ]; then
      PROJECT_ID="$(jq -r '.PROJECT_ID // empty' "$ENV_FILE")"
    fi
    if [ -z "$BACKEND_ACCOUNT_NAME" ]; then
      BACKEND_ACCOUNT_NAME="$(jq -r '.BACKEND_SERVICE_ACCOUNT // empty' "$ENV_FILE" | sed 's/@.*//')"
    fi
  elif command -v python3 >/dev/null 2>&1; then
    if [ -z "$PROJECT_ID" ]; then
      PROJECT_ID="$(python3 -c "import json; print(json.load(open('$ENV_FILE')).get('PROJECT_ID', ''))")"
    fi
    if [ -z "$BACKEND_ACCOUNT_NAME" ]; then
      BACKEND_ACCOUNT_NAME="$(python3 -c "import json, re; sa = json.load(open('$ENV_FILE')).get('BACKEND_SERVICE_ACCOUNT', ''); print(re.sub(r'@.*', '', sa))")"
    fi
  fi
fi

if [ -z "$PROJECT_ID" ] || [ -z "$BACKEND_ACCOUNT_NAME" ]; then
  echo "Usage: $0 [--env-file <path>] [PROJECT_ID] [BACKEND_ACCOUNT_NAME]"
  echo ""
  echo "PROJECT_ID and BACKEND_ACCOUNT_NAME are required. Provide them as arguments"
  echo "or set PROJECT_ID and BACKEND_SERVICE_ACCOUNT in the env file."
  echo ""
  echo "Example:"
  echo "  $0 focus-local-dev focus-backend"
  exit 1
fi

SERVICE_ACCOUNT_EMAIL="${BACKEND_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Creating service account: ${BACKEND_ACCOUNT_NAME} in project: ${PROJECT_ID}"
gcloud iam service-accounts create "${BACKEND_ACCOUNT_NAME}" \
  --project="${PROJECT_ID}" \
  --display-name="${BACKEND_ACCOUNT_NAME}" \
  --description="Backend service account for ${PROJECT_ID}"

echo "Assigning Firebase Admin SDK Administrator Service Agent role..."
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/firebase.sdkAdminServiceAgent"

echo "Assigning Cloud Datastore User role..."
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/datastore.user"

echo ""
echo "Service account created: ${SERVICE_ACCOUNT_EMAIL}"
echo ""
echo "To create and download a JSON key, run:"
echo "  gcloud iam service-accounts keys create ${BACKEND_ACCOUNT_NAME}-key.json \\"
echo "    --project=${PROJECT_ID} \\"
echo "    --iam-account=${SERVICE_ACCOUNT_EMAIL}"

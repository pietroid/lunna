#!/usr/bin/env bash
set -euo pipefail

# deploy-web-local.sh
#
# Build and deploy the Flutter web app locally on the Raspberry Pi.
#
# Usage:
#   scripts/deploy-web-local.sh
#
# Must be run from inside the Raspberry Pi where the repo is cloned.
# It builds the Flutter web app and copies the output to /opt/focus/web,
# which is mounted by the nginx container.
#
# Requirements:
#   - Flutter SDK installed on the Pi.
#   - app/env/production.json exists with GOOGLE_SIGN_IN_CLIENT_ID and PROJECT_ID.
#   - The backend has already been deployed (so the nginx container is running).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE="$ROOT_DIR/env/production.json"
if [ ! -f "$ENV_FILE" ]; then
  echo "Error: production env file not found at $ENV_FILE"
  echo "Copy env/production.example.json to env/production.json and fill in your values."
  exit 1
fi

WEB_ENV_FILE="$(mktemp /tmp/focus-web-env.XXXXXX.json)"
trap 'rm -f "$WEB_ENV_FILE"' EXIT

if command -v jq >/dev/null 2>&1; then
  jq '.API_BASE_URL = "/api/" | .FLAVOR = "production"' "$ENV_FILE" > "$WEB_ENV_FILE"
elif command -v python3 >/dev/null 2>&1; then
  python3 -c "
import json
with open('$ENV_FILE') as f:
    data = json.load(f)
data['API_BASE_URL'] = '/api/'
data['FLAVOR'] = 'production'
with open('$WEB_ENV_FILE', 'w') as f:
    json.dump(data, f)
"
else
  echo "Error: jq or python3 is required to generate the web env file."
  exit 1
fi

cd "$ROOT_DIR"

echo "Building Flutter web app for production..."
flutter build web \
  --release \
  --dart-define-from-file "$WEB_ENV_FILE"

WEB_ROOT="/opt/focus/web"
NGINX_CONTAINER="focus-web"

echo ""
echo "Copying build output to ${WEB_ROOT}..."
mkdir -p "${WEB_ROOT}"
rsync -avz --delete "$ROOT_DIR/build/web/" "${WEB_ROOT}/"

echo ""
echo "Reloading nginx..."
docker exec "${NGINX_CONTAINER}" nginx -s reload 2>/dev/null || {
  echo "Warning: ${NGINX_CONTAINER} container is not running."
  echo "Deploy the backend first."
  exit 1
}

echo ""
echo "Web deployment complete."
echo "Visit http://$(hostname -I | awk '{print $1}')"

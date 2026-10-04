#!/usr/bin/env bash
set -euo pipefail

# update_firebase_config.sh
#
# Re-downloads/regenerates Firebase configuration files for the production and
# dev flavors. The dev configuration uses the focus-local-dev Firebase project
# with a localhost backend.
#
# Project IDs are read from the committed env files:
#   - app/env/production.json  -> PROD_PROJECT_ID
#   - app/env/dev.json         -> DEV_PROJECT_ID
#
# If an env file does not contain a PROJECT_ID, the defaults are used:
#   - Production: focus-production
#   - Dev:        focus-local-dev

# Navigate to the project root (where this script lives)
cd "$(dirname "$0")"

read_json_field() {
  local file="$1"
  local key="$2"
  local default="$3"

  if [ -f "$file" ] && command -v jq >/dev/null 2>&1; then
    jq -r ".${key} // empty" "$file" || true
  elif [ -f "$file" ] && command -v python3 >/dev/null 2>&1; then
    python3 -c "import json; print(json.load(open('$file')).get('$key', ''))" || true
  else
    echo ""
  fi
}

PROD_PROJECT_ID="$(read_json_field env/production.json PROJECT_ID focus-production)"
DEV_PROJECT_ID="$(read_json_field env/dev.json PROJECT_ID focus-local-dev)"

# Fall back to defaults if the env files did not contain the values
PROD_PROJECT_ID="${PROD_PROJECT_ID:-focus-production}"
DEV_PROJECT_ID="${DEV_PROJECT_ID:-focus-local-dev}"

echo "Updating Firebase configs..."
echo "  Production project: $PROD_PROJECT_ID"
echo "  Dev project:        $DEV_PROJECT_ID"
echo ""

# Make sure flavor directories exist
mkdir -p android/app/src/production
mkdir -p android/app/src/dev

# Remove any stale default-generated file so we only keep the per-flavor files
rm -f lib/firebase_options.dart
rm -f android/app/google-services.json

echo "=> Configuring production flavor..."
flutterfire configure \
  --project="$PROD_PROJECT_ID" \
  --out=lib/firebase_options_production.dart \
  --platforms=android,ios,web \
  --ios-bundle-id=com.pietroid.focus \
  --android-package-name=com.pietroid.focus \
  --overwrite-firebase-options \
  --yes

# Move the generated Android config into the production flavor
mv android/app/google-services.json android/app/src/production/google-services.json

# Keep a backup of the production iOS plist before we overwrite it with dev
# (flutterfire configure always writes GoogleService-Info.plist).
cp ios/Runner/GoogleService-Info.plist ios/Runner/GoogleService-Info.plist.prod

echo ""
echo "=> Configuring dev flavor..."
flutterfire configure \
  --project="$DEV_PROJECT_ID" \
  --out=lib/firebase_options_dev.dart \
  --platforms=android,ios,web \
  --ios-bundle-id=com.pietroid.focus.dev \
  --android-package-name=com.pietroid.focus.dev \
  --overwrite-firebase-options \
  --yes

# Move the generated Android config into the dev flavor
mv android/app/google-services.json android/app/src/dev/google-services.json

# Rename the dev plist and restore the production plist
mv ios/Runner/GoogleService-Info.plist ios/Runner/GoogleService-Info-Dev.plist
mv ios/Runner/GoogleService-Info.plist.prod ios/Runner/GoogleService-Info.plist

echo ""
echo "Firebase config update complete."
echo ""
echo "Generated files:"
echo "  lib/firebase_options_production.dart"
echo "  lib/firebase_options_dev.dart"
echo "  android/app/src/production/google-services.json"
echo "  android/app/src/dev/google-services.json"
echo "  ios/Runner/GoogleService-Info.plist"
echo "  ios/Runner/GoogleService-Info-Dev.plist"

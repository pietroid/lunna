#!/usr/bin/env bash
# Stamps a brand on a Flutter web build: its name and colours in index.html
# and manifest.json, and its icons, favicon and splash from brands/<brand>/web.
#
#   flutter build web --release --dart-define-from-file env/lunna.production.json
#   tool/brand_web.sh lunna            # defaults to build/web
set -euo pipefail

brand="${1:?usage: tool/brand_web.sh focus|lunna [build/web]}"
app="$(cd "$(dirname "$0")/.." && pwd)"
out="${2:-$app/build/web}"

case "$brand" in
  focus) name="Focus"; bg="#000000"; bar="black" ;;
  lunna) name="Lunna"; bg="#FFFFFF"; bar="default" ;;
  *) echo "unknown brand: $brand" >&2; exit 1 ;;
esac

cp -R "$app/brands/$brand/web/." "$out/"
for file in "$out/index.html" "$out/manifest.json"; do
  sed -e "s/__APP_NAME__/$name/g" -e "s/__APP_BG__/$bg/g" \
    -e "s/__STATUS_BAR__/$bar/g" "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
done

if grep -q "__APP_\|__STATUS_BAR__" "$out/index.html" "$out/manifest.json"; then
  echo "placeholders left in $out" >&2
  exit 1
fi
echo "$out is $name"

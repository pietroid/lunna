#!/bin/sh
# Shoots the Live Activity views on this Mac (SwiftUI ImageRenderer), for
# the design prints: shoot.sh <out>. Not part of any build.
set -e
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
curl -sfL -o "$work/Onest.ttf" "https://github.com/google/fonts/raw/main/ofl/onest/Onest%5Bwght%5D.ttf"
cp "$here/../../../packages/app_ui/assets/brand/lunna.png" "$work/LunnaMark.png"
swiftc -swift-version 5 "$here/../BlockActivityViews.swift" "$here/main.swift" -o "$work/render"
"$work/render" "${1:-$work/shots}"

#!/usr/bin/env bash
# Renders (macOS: Chrome + sips) a proposal board to PNGs: board.png plus one screenN.png per column.
# Usage: render.sh <board.html> <out_dir> [screens=4]
set -euo pipefail
html=$(cd "$(dirname "$1")" && pwd)/$(basename "$1"); out=$2; n=${3:-4}
mkdir -p "$out"
w=$((96 + n*390 + (n-1)*56))
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu \
  --hide-scrollbars --force-device-scale-factor=2 --virtual-time-budget=8000 \
  --window-size=$w,1260 --screenshot="$out/board.png" "file://$html" 2>/dev/null
for i in $(seq 1 "$n"); do
  x=$((48 + (i-1)*446))
  sips -c 2340 780 --cropOffset 96 $((x*2)) "$out/board.png" --out "$out/screen$i.png" >/dev/null
done
ls "$out"

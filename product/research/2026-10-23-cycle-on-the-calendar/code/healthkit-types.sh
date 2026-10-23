#!/usr/bin/env bash
# Every HealthKit category type about the cycle, from Apple's documentation
# JSON, into data/healthkit-cycle-types.txt. There is no prediction type.
#   bash code/healthkit-types.sh
cd "$(dirname "$0")/.."
curl -s https://developer.apple.com/tutorials/data/documentation/healthkit/hkcategorytypeidentifier.json |
python3 -I -c '
import json, sys
d = json.load(sys.stdin)
words = ["menstru", "ovulat", "cervical", "pregnan", "contracep", "lactat", "progester", "cycle", "intermenstrual", "sexual", "predict"]
for v in sorted(d["references"].values(), key=lambda v: v.get("title", "")):
    t = v.get("title", ""); a = "".join(x.get("text", "") for x in v.get("abstract", []) if isinstance(x, dict))
    if any(w in (t + a).lower() for w in words): print(f"{t}: {a}")
' > data/healthkit-cycle-types.txt
cat data/healthkit-cycle-types.txt

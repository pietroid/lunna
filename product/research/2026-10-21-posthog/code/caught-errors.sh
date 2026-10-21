#!/usr/bin/env bash
# Every place the app catches an error itself, so Flutter's global handlers
# (and PostHog's autocapture behind them) never see it. Run from the topic
# folder: bash code/caught-errors.sh > data/caught-errors.txt
set -euo pipefail
root="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$root/app"
grep -rn "on Object catch\|on DioException catch\|catch (" lib packages/*/lib \
  | grep -v "/gen/" | sort
echo
echo "total: $(grep -rn "on Object catch\|on DioException catch\|catch (" lib packages/*/lib | grep -vc "/gen/")"

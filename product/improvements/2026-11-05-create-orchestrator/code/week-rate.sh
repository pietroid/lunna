#!/bin/sh
# USD (API-equivalent) per point of the weekly window, fitted over every queue run.
# Usage: sh week-rate.sh [logs dir]   (default .git/queue/logs)
for f in $(ls -tr "${1:-.git/queue/logs}"/*.jsonl); do
  jq -rs '[.[]|select(.type=="rate_limit_event")|.rate_limit_info.unifiedWindows.seven_day.utilization // empty] as $w
    | ([.[]|select(.type=="result")][0].total_cost_usd // empty) as $u
    | if ($w|length)>1 and $u then "\($u) \($w[0]) \($w[-1])" else empty end' "$f" 2>/dev/null
done | awk '{d=$3-$2; if(d>=0 && d<0.2){U+=$1; W+=d; n++}} END{printf "runs=%d usd=%.2f week_pts=%.1f usd_per_pt=%.2f\n",n,U,W*100,U/(W*100)}'

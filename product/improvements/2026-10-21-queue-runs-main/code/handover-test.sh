#!/usr/bin/env bash
# The handover, end to end, on a copy: a test LaunchAgent runs the stale
# queue.mjs (5daf05d, what the real one runs) from a checkout that is behind
# its origin, and `adopt`, started from an issue worktree before main has the
# runner, has to move it onto <worktrees>/.runner by itself.
#
# Usage: code/handover-test.sh   (from the repo root; about 4 minutes)
# Touches nothing real: its own label, a bare origin in a temp dir, a config
# whose repo doesn't exist (every tick fails harmlessly) and a throwaway topic.
set -euo pipefail
repo=$(pwd)
T=$(mktemp -d "${TMPDIR:-/tmp}/lq-handover.XXXX"); T=$(cd "$T" && pwd -P)
label=dev.pietroid.lunna-queue-test
plist=~/Library/LaunchAgents/$label.plist
uid=$(id -u)
node=$(command -v node)
helper=$label-handover
cleanup() {
  for l in $label $helper; do launchctl bootout "gui/$uid/$l" 2>/dev/null || true; rm -f ~/Library/LaunchAgents/$l.plist; done
  rm -rf "$T"
}
trap cleanup EXIT
say() { echo "$(date +%T) $*"; }

git init -q --bare "$T/origin.git"
git clone -q "$repo" "$T/checkout" 2>/dev/null
cd "$T/checkout"
git remote set-url origin "$T/origin.git"
git checkout -q -b main
git -C "$repo" show 5daf05d:.tool/queue.mjs > .tool/queue.mjs
git -c user.name=t -c user.email=t@t commit -qam 'stale queue' && git push -q origin main
mkdir -p .git/queue
cat > .git/queue/config.json <<EOF
{ "repo": "pietroid/no-such-repo-for-a-test", "owner": "pietroid", "topic": "lq-test-$RANDOM$RANDOM",
  "worktrees": "$T/wt", "timeZone": "UTC" }
EOF

# The stale daemon, as the real one: launchd runs the checkout's queue.mjs.
cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key><array><string>$node</string><string>$T/checkout/.tool/queue.mjs</string><string>run</string></array>
  <key>WorkingDirectory</key><string>$T/checkout</string>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>$PATH</string></dict>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/><key>ThrottleInterval</key><integer>60</integer>
  <key>StandardOutPath</key><string>$T/checkout/.git/queue/daemon.log</string>
  <key>StandardErrorPath</key><string>$T/checkout/.git/queue/daemon.log</string>
</dict></plist>
EOF
launchctl bootstrap "gui/$uid" "$plist"; launchctl kickstart "gui/$uid/$label"
sleep 3
stale=$(launchctl print "gui/$uid/$label" | awk '/^\tpid = /{print $3}')
say "stale daemon pid $stale runs $T/checkout/.tool/queue.mjs"

# An issue worktree with the new queue, its PR not merged yet.
git worktree add -q -b queue/test "$T/issue" main
cp "$repo/.tool/queue.mjs" "$T/issue/.tool/queue.mjs"
git -C "$T/issue" -c user.name=t -c user.email=t@t commit -qam 'the runner and the handover'
# A log left by an earlier try, written from this shell (sandboxed under
# Claude Code): launchd could not open it and the real job died with EX_CONFIG.
echo "an earlier try" > .git/queue/handover.log
LUNNA_QUEUE_AGENT=$label node "$T/issue/.tool/queue.mjs" adopt
LUNNA_QUEUE_AGENT=$label node "$T/issue/.tool/queue.mjs" adopt   # a second adopt starts nothing
sleep 2
say "handover jobs: $(pgrep -f "$T/checkout/.git/queue/handover.mjs handover" | wc -l | tr -d ' ') (want 1, its own launchd job: $helper)"

say "merging the PR into the test origin"
git -C "$T/issue" push -q origin queue/test:main
start=$SECONDS
for _ in $(seq 1 240); do
  grep -q 'handover: ✓' .git/queue/handover.log 2>/dev/null && break
  sleep 2
done
say "handover took $((SECONDS - start))s after the merge"
echo "--- handover.log"; cat .git/queue/handover.log
echo "--- daemon.log"; cat .git/queue/daemon.log
sleep 5
now=$(launchctl print "gui/$uid/$label")
pid=$(awk '/^\tpid = /{print $3}' <<<"$now")
args=$(sed -n '/^\targuments = {/,/}/p' <<<"$now")
echo "--- launchd now"; echo "$args"; echo "pid $pid"
ok() { if eval "$2"; then echo "✓ $1"; else echo "✗ $1"; fi; }
ok "the stale pid $stale is gone" "! kill -0 $stale 2>/dev/null"
ok "launchd runs the runner's queue.mjs" "grep -q '$T/wt/.runner/.tool/queue.mjs' <<<\"\$args\""
ok "the runner is at the test origin's main" "[ \$(git -C $T/wt/.runner rev-parse HEAD) = \$(git rev-parse origin/main) ]"
ok "the new daemon is alive" "kill -0 ${pid:-0} 2>/dev/null"
ok "the handover job unloaded itself and its plist is gone" "! launchctl print gui/$uid/$helper >/dev/null 2>&1 && [ ! -e ~/Library/LaunchAgents/$helper.plist ]"
ok "the checkout was not changed (still the stale commit, clean)" "[ \"\$(git log -1 --format=%s)\" = 'stale queue' ] && [ -z \"\$(git status --porcelain)\" ]"
say "stale copies launchd started in between, sent off by the lock: $(grep -c 'Another .tool/queue run is going' .git/queue/daemon.log || true)"
echo "--- ls from the runner"; LUNNA_QUEUE_AGENT=$label node "$T/wt/.runner/.tool/queue.mjs" ls | head -2

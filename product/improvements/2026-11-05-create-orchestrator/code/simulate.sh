#!/bin/bash
# Runs the real .tool/queue.mjs through a create issue's whole life, against
# fake gh, claude and npm (code/sim/), in a throwaway clone with a bare
# origin: split, approve all on the parent, a mockup approved, its build
# from the mockup's branch (its run hits a limit after its output), merge,
# the parent closing; then a second parent whose mockup gets "no".
# Usage, from the repo root: bash product/improvements/2026-11-05-create-orchestrator/code/simulate.sh
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd); repo=$(pwd)
sim=$(mktemp -d)/sim; mkdir -p "$sim"
git clone -q --bare "$repo" "$sim/origin.git"
git clone -q "$sim/origin.git" "$sim/work"
cp "$repo/.tool/queue.mjs" "$sim/work/.tool/queue.mjs"
mkdir -p "$sim/bin" "$sim/work/.git/queue"
cp "$here/sim/gh" "$here/sim/claude" "$sim/bin/"; printf '#!/bin/sh\nexit 0\n' > "$sim/bin/npm"; chmod +x "$sim/bin/"*
echo '{"repo":"sim/lunna","owner":"owner","topic":"sim","worktrees":"'"$sim"'/wt","timeZone":"UTC"}' > "$sim/work/.git/queue/config.json"
export PATH="$sim/bin:$PATH" SIM_DB="$sim/db.json" SIM_LOG="$sim/log.txt" SIM_LIMIT_AFTER=1
: > "$SIM_LOG"
cd "$sim/work"
gh issue create --title "Em seguida como fila" --label create --body-file - <<< "A fila." >/dev/null
tick() { node .tool/queue.mjs tick >> "$sim/daemon.txt" 2>&1 || { echo "✗ tick failed"; tail -20 "$sim/daemon.txt"; exit 1; }; }
state() { node -e "const s=JSON.parse(require('fs').readFileSync('.git/queue/issues/$1.json','utf8'));console.log([s.status,s.gate??'-',s.next?.phase??'-'].join(' '))"; }
check() { if [ "$(state "$1")" = "$2" ]; then echo "✓ #$1: $2 ($3)"; else echo "✗ #$1: $(state "$1"), wanted $2 ($3)"; fail=1; fi; }
fail=0

tick; tick                                    # queued, then split
check 1 "waiting split -" "parent split into 2 children"
check 2 "waiting proposed -" "mockup proposed"
check 3 "waiting proposed -" "build proposed, after #2"
gh sim-say 1 approve; tick                   # approve all on the parent → mockup runs; build waits
check 2 "waiting design -" "mockup ran, waits at its gate"
check 3 "waiting - build" "build approved, waiting for its mockup"
gh sim-say 2 approve; tick                   # mockup accepted
check 2 "done - -" "mockup accepted: PR closed, issue closed"
tick                                         # build runs from the mockup's branch
check 3 "waiting review -" "build ran (a limit after its output still counts as done)"
git -C "$sim/origin.git" show queue/3-construir-a-fila:app/lib/fila_preview.dart >/dev/null 2>&1 \
  && echo "✓ the build's branch has the mockup's preview" || { echo "✗ the build's branch lacks the mockup's files"; fail=1; }
gh sim-say 3 approve; tick                   # merge
check 3 "done - -" "build merged"
tick                                         # the parent sees no child open
check 1 "done - -" "parent closed"

gh issue create --title "Outra coisa" --label create --body-file - <<< "Outra." >/dev/null   # → #6
tick; tick
gh sim-say 7 "no"; tick                      # no on the mockup: it and its build go to the backlog
check 7 "backlog - -" "mockup said no"
check 8 "backlog - -" "its build follows it"
tick
check 6 "done - -" "parent closes: everything is in the backlog"

gh issue create --title "Terceira" --label create --body-file - <<< "Mais." >/dev/null   # → #9
tick; tick
gh sim-say 9 "build the first one for now"; tick; tick   # answered on the pieces, not split again
check 10 "waiting design -" "the first piece started (and ran) on a reply"
check 11 "waiting proposed -" "the other piece stays proposed"
node -e "const s=JSON.parse(require('fs').readFileSync('.git/queue/issues/9.json','utf8'));process.exit(JSON.stringify(s.children)==='[10,11]'?0:1)" \
  && echo "✓ #9: still the same two pieces (no new split)" || { echo "✗ #9 was split again"; fail=1; }

echo; cat "$SIM_LOG"
[ $fail = 0 ] && echo "✓ all checks passed" || { echo "✗ some checks failed; daemon log: $sim/daemon.txt"; exit 1; }

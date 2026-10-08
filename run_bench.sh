#!/usr/bin/env bash
# Shared SWE-bench benchmark engine (multi-session, resumable).
#
# Each model keeps ONE persistent run-id. preds.json accumulates across sessions;
# mini-SWE-agent skips instances already in preds.json, so every session runs only
# NEW tasks (no doubling). At the end of every session all accumulated predictions
# are re-graded, giving the cumulative score.
#
# Usage: run_bench.sh <CONFIG.yaml> <RUN_ID> [N_TASKS]
#   N_TASKS = number of NEW tasks to attempt this session (default 10)
#
# Time budget: ~27 min/task on a local llama.cpp server with 1 worker,
# so N=5..8 fits a 2-4h window; N=10 is ~4.5h.
#
# Paths: venv / SWE-bench / swe-bench-tasks are auto-detected in this script's
# directory or its parent; override with SWEB_VENV, SWEB_REPO, SWEB_TASKS.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

VENV="${SWEB_VENV:-}"
REPO="${SWEB_REPO:-}"
TASKS="${SWEB_TASKS:-}"
for base in "$SCRIPT_DIR" "$(dirname "$SCRIPT_DIR")"; do
    [ -z "$VENV" ] && [ -d "$base/venv" ] && VENV="$base/venv"
    [ -z "$REPO" ] && [ -d "$base/SWE-bench" ] && REPO="$base/SWE-bench"
    [ -z "$TASKS" ] && [ -d "$base/swe-bench-tasks" ] && TASKS="$base/swe-bench-tasks"
done
[ -n "$VENV" ] && [ -n "$REPO" ] && [ -n "$TASKS" ] || {
    echo "ERROR: could not locate venv / SWE-bench / swe-bench-tasks." >&2
    echo "Set SWEB_VENV, SWEB_REPO, SWEB_TASKS." >&2
    exit 1
}

CONFIG="$1"
RUN_ID="$2"
N="${3:-10}"

PRED="$REPO/logs/inference/$RUN_ID/preds.json"
DONE=0
if [ -f "$PRED" ]; then
    DONE=$("$VENV/bin/python" -c "import json; print(len(json.load(open('$PRED'))))")
fi
END=$((DONE + N))

cd "$REPO"
export MSWEA_COST_TRACKING=ignore_errors

echo "=== [$RUN_ID] inference: slice 0:$END — $DONE already done, ~$N new ==="
"$VENV/bin/swebench" infer verified -c "$CONFIG" -r "$RUN_ID" -w 1 -- --slice "0:$END"

DONE_NOW=$("$VENV/bin/python" -c "import json; print(len(json.load(open('$PRED'))))")
echo "=== [$RUN_ID] grading all $DONE_NOW accumulated predictions (docker) ==="
"$VENV/bin/swebench" eval verified -p "logs/inference/$RUN_ID/preds.json" \
    --run-id "$RUN_ID" -j 4 --task-repo "$TASKS"

echo "=== [$RUN_ID] cumulative report ==="
"$VENV/bin/swebench" report "$RUN_ID" -d verified

#!/usr/bin/env bash
# Model 2: qwen3.8-27b @ tr4:8080
# (from i7: reaches tr4 directly; from tr4: same endpoint as localhost)
# Usage: ./run_model2.sh [RUN_ID] [N_TASKS]
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec "$SCRIPT_DIR/run_bench.sh" "$SCRIPT_DIR/models/model2.yaml" "${1:-m2-slice}" "${2:-10}"

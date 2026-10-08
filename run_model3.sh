#!/usr/bin/env bash
# Model 3: qwen3.8-flash @ tr4:8080
# Usage: ./run_model3.sh [RUN_ID] [N_TASKS]
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec "$SCRIPT_DIR/run_bench.sh" "$SCRIPT_DIR/models/model3.yaml" "${1:-m3-slice}" "${2:-10}"

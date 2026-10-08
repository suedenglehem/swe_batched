#!/usr/bin/env bash
# Model 1: swift-1.5-iq3_xxs @ localhost:8080 (i7)
# Usage: ./run_model1.sh [RUN_ID] [N_TASKS]
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec "$SCRIPT_DIR/run_bench.sh" "$SCRIPT_DIR/models/model1.yaml" "${1:-m1-slice}" "${2:-10}"

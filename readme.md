# swe_batched — batched, resumable SWE-bench runs for local models

Scripts for running [SWE-bench Verified](https://github.com/SWE-bench/SWE-bench)
evaluations against local OpenAI-compatible model servers (llama.cpp style),
in **daily takes**: each session runs a few *new* tasks, never repeats a task,
and ends with a cumulative score.

## How the batching works

Each model has one persistent **run-id** — just the name of its results folder:

```
SWE-bench/logs/inference/<run-id>/preds.json     # all patches; one entry per task
SWE-bench/logs/evaluation/<run-id>/results.json  # grading results
```

`preds.json` is the memory of which tasks are done. Every session:

1. counts entries in `preds.json` → `done`
2. runs slice `0:(done + N)` — mini-SWE-agent **skips every task already in
   `preds.json`**, so only ~N new tasks run (no doubling; a task interrupted
   mid-flight has no entry and is retried)
3. re-grades **all** accumulated patches in Docker
4. prints the cumulative report — the last block is your day-end score

Time budget: ~27 min/task with 1 worker on a local llama.cpp server.
`N=4` ≈ 2 h, `N=8` ≈ 3.5–4 h, `N=10` ≈ 4.5 h.

## Scripts

| script | model | endpoint | default run-id |
|---|---|---|---|
| `run_model1.sh` | swift-1.5-iq3_xxs | localhost:8080 (i7) | `m1-slice` |
| `run_model2.sh` | qwen3.8-27b | tr4:8080 | `m2-slice` |
| `run_model3.sh` | qwen3.8-flash | tr4:8080 | `m3-slice` |
| `run_model.sh` | **any** model | **any** endpoint | `bench-<model>` |
| `run_bench.sh` | shared engine (used by all) | — | — |

You never need to type the run-id. The only argument you'll use is N:

```bash
./run_model3.sh 8          # 8 new tasks today, then cumulative score
```

### Generic script

```bash
./run_model.sh <MODEL_NAME> <HOST:PORT> [RUN_ID] [N_TASKS]

./run_model.sh qwen3.8-flash localhost:8080
./run_model.sh swift-1.5-iq3_xxs 192.168.0.33:8080 bench-swift 4
```

`MODEL_NAME` must be the id exactly as listed by `GET /v1/models`. The config
is generated on the fly into `models/gen-<model>.yaml`.

## Daily workflow (example, 3 models, 2–4 h/day per machine)

```
DAY 1   i7:  ./run_model1.sh 8            # swift
        tr4: ./run_model3.sh 8            # flash (server currently on flash)
DAY 2   i7:  ./run_model1.sh 8
        tr4: [swap server to qwen3.8-27b] && ./run_model2.sh 8
DAY 3   i7:  ./run_model1.sh 8
        tr4: [swap server to qwen3.8-flash] && ./run_model3.sh 8
...     keep alternating flash / 27b on tr4; swift runs daily on i7.
```

tr4 serves **one model at a time** on 8080 — start the server with the model
matching the script you're about to run.

## Scores

Printed automatically at the end of every run:

```
Scorecard: 4 out of 5 resolved (80.0%)
```

Re-print anytime:

```bash
cd SWE-bench
../venv/bin/swebench report m3-slice -d verified
```

## Setup (per machine)

```bash
python3 -m venv venv
venv/bin/pip install -e ./SWE-bench mini-swe-agent
git clone --depth 1 https://github.com/SWE-bench/swe-bench-tasks.git
docker reachable by your user (docker ps works)
```

The scripts auto-detect `venv/`, `SWE-bench/`, `swe-bench-tasks/` in their own
directory or its parent; override with `SWEB_VENV`, `SWEB_REPO`, `SWEB_TASKS`.

## Gotchas

- `cost_tracking: ignore_errors` is required in every config — litellm can't
  price local models and mini-SWE-agent raises without it.
- The Strata-flavored proxy on i7 rejects the Host header `i7:8080`
  (DNS-rebinding protection) — reach it by IP (`192.168.0.33:8080`) from other
  machines.
- Grading pulls per-task Docker images on first use (cached afterwards).
- Don't edit a script while it is running (bash re-reads files mid-execution).

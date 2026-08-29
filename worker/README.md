# Qwen GPU coding worker

This directory prepares the coding side of the paid GPU pilot. vLLM remains the inference server from `docker-compose.yml`; Qwen Code runs on the GPU host and talks to the local OpenAI-compatible vLLM endpoint.

## Target repository

The worker uses the private repository:

```text
ScoreSymphony/ScoreSymphony-Agent-VPS
```

It is cloned locally as:

```text
~/scoresymphony-workspace/scoresymphony-infrastructure
```

The task entrypoint inside that repository is:

```text
TASKS/README.md
```

## One-time preparation on the GPU host

Clone this public deployment repository if it is not already available in the shell:

```bash
git clone https://github.com/ScoreSymphony/qwen-vllm-gpu.git
cd qwen-vllm-gpu
```

Create the private worker environment file:

```bash
cp worker/.env.example worker/.env
```

Edit `worker/.env` and set only the required secret:

```text
GITHUB_TOKEN=...
```

Use a fine-grained GitHub token scoped only to `ScoreSymphony/ScoreSymphony-Agent-VPS`. `Contents: read/write` is enough for clone/fetch and a later push if the task explicitly requires one. The `.env` file is ignored by Git.

## Start the complete pilot

After the vLLM Compose deployment has been started, run:

```bash
bash worker/run-pilot.sh
```

This single command:

1. starts GPU/system/vLLM monitoring immediately;
2. installs Qwen Code with the official standalone installer if necessary;
3. installs `uv` if necessary;
4. clones or refreshes the target repository without overwriting dirty work;
5. verifies `TASKS/README.md` and TASK-001 through TASK-007;
6. waits for the local vLLM health endpoint;
7. verifies `/v1/models` and a real chat completion;
8. starts Qwen Code headlessly against `Qwen3-Coder-Next-FP8`;
9. executes the TASK-001 → TASK-007 chain autonomously;
10. preserves Qwen output, Git state and monitoring evidence when the run ends.

## Qwen/vLLM binding

Defaults:

```text
OPENAI_BASE_URL=http://127.0.0.1:8000/v1
OPENAI_MODEL=Qwen3-Coder-Next-FP8
OPENAI_API_KEY=local-vllm
```

Qwen Code requires a non-empty OpenAI-compatible API key value. The local vLLM baseline is not configured to validate this placeholder key.

## Autonomous mode and budget

The pilot defaults to:

```text
QWEN_APPROVAL_MODE=yolo
QWEN_MAX_WALL_TIME=2h
```

`yolo` is required for an unattended task chain because Qwen Code otherwise pauses for tool approvals. It does not add a sandbox: commands run with the Unix permissions of the user that launched Qwen Code. Run the worker under the intended non-privileged account where possible.

The wall-time budget can be changed in `worker/.env` before the run.

## Evidence

Per-run Qwen logs:

```text
worker/logs/<RUN_ID>/
├── qwen-output.log
└── run-metadata.txt
```

Per-run performance data:

```text
monitoring/logs/<RUN_ID>/
```

Both runtime log directories are ignored by Git.

## Individual steps

For diagnosis, each stage can also be run separately:

```bash
bash worker/bootstrap.sh
bash worker/preflight.sh
bash worker/run-task-chain.sh
```

Do not start `run-task-chain.sh` until `preflight.sh` reports `GPU WORKER PREFLIGHT: PASS`.

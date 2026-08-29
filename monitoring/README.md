# Monitoring

Lightweight host-side monitoring for the paid GPU pilot. It is intentionally independent of Prometheus/Grafana and writes plain CSV/log files that can be archived and analyzed after the run.

## What is recorded

`gpu-monitor.sh` records every sampling interval:

- UTC timestamp
- GPU index and model name
- GPU utilization
- VRAM used / total
- GPU temperature
- power draw / power limit
- SM and memory clocks

`system-monitor.sh` records:

- CPU utilization
- load averages
- RAM used / available
- swap usage
- root-filesystem usage

`vllm-monitor.sh` snapshots all metrics exposed by the local vLLM `/metrics` endpoint whose names begin with `vllm:` or `vllm_`. This preserves request, token, cache and latency metrics exposed by the installed vLLM version without hard-coding one metric schema.

`run-monitoring.sh` starts all three monitors, captures the vLLM container log, and writes an environment snapshot containing NVIDIA, Docker, memory and filesystem information.

## Start

Run this on the GPU host before beginning the actual coding workload:

```bash
cd qwen-vllm-gpu
./monitoring/run-monitoring.sh
```

Default sampling interval: `5` seconds.

To change it:

```bash
MONITOR_INTERVAL=2 ./monitoring/run-monitoring.sh
```

The script can also be started while the vLLM container is still starting. GPU/system monitoring begins immediately; vLLM metrics and container logs become available once the service/container exists.

Stop monitoring with `Ctrl+C`. The collected data is preserved.

## Output

Each run receives its own UTC run ID:

```text
monitoring/logs/20260829T120000Z/
├── environment.txt
├── gpu-metrics.csv
├── system-metrics.csv
├── vllm-metrics.log
└── vllm-container.log
```

Runtime logs are ignored by Git through `.gitignore` and should not be committed accidentally.

## Expected container/API defaults

The scripts assume:

```text
container: scoresymphony-qwen-vllm
vLLM metrics: http://127.0.0.1:8000/metrics
```

Override if required:

```bash
VLLM_CONTAINER=other-name \
VLLM_METRICS_URL=http://127.0.0.1:8000/metrics \
./monitoring/run-monitoring.sh
```

## Minimum pilot evidence

For a useful GPU pilot, preserve the complete run directory from model startup through the coding workload. The resulting data should be sufficient to compare GPU utilization, VRAM headroom, power draw, host resource pressure, vLLM request/token metrics, startup behavior and total elapsed time.

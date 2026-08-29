# qwen-vllm-gpu

Minimal Docker Compose deployment for **Qwen3-Coder-Next-FP8** with **vLLM** on a single NVIDIA GPU.

## Intended use

This repository is designed to be imported directly into a Docker/Compose manager such as Hostinger. The model weights are **not** stored in GitHub. They must already exist on the GPU host.

Default expected model location:

```text
/models/Qwen3-Coder-Next-FP8
```

You can override that host path with `QWEN_MODEL_PATH`.

## Baseline

- Model: `Qwen3-Coder-Next-FP8`
- vLLM image: `vllm/vllm-openai:v0.28.0-ubuntu2404`
- Single GPU / tensor parallel size 1
- Initial context length: 32768 tokens
- GPU memory utilization: 0.90
- FP8 KV cache
- Prefix caching enabled
- Automatic tool choice enabled
- Tool parser: `qwen3_coder`
- API bound only to host loopback: `127.0.0.1:8000`

## Model preparation

Before deployment, copy the complete model directory to the GPU host and verify that it contains all 40 safetensor shards plus `model.safetensors.index.json`.

If your model is stored elsewhere, set for example:

```text
QWEN_MODEL_PATH=/workspace/models/Qwen3-Coder-Next-FP8
```

## Start

With Docker Compose directly:

```bash
docker compose up -d
```

Check status:

```bash
docker compose ps
```

Follow model loading:

```bash
docker compose logs -f vllm
```

Once healthy, the local OpenAI-compatible API is available on:

```text
http://127.0.0.1:8000
```

The loopback binding is deliberate. The deployment does not expose vLLM publicly by default.

# qwen-vllm-gpu

Minimal Docker Compose deployment for **Qwen3-Coder-Next-FP8** with **vLLM** on a single NVIDIA GPU.

## Intended use

This repository is designed to be imported directly into a Docker/Compose manager such as Hostinger.

The model weights are **not stored in GitHub**. On the first start, vLLM downloads the pinned Hugging Face model automatically:

```text
Qwen/Qwen3-Coder-Next-FP8
```

Pinned revision:

```text
da6e2ed27304dd39abadd9c82ef50e8de67bdd4c
```

The Hugging Face cache is stored in a named Docker volume (`hf-cache`), so container recreation on the same GPU host does not require downloading the model again as long as that volume is preserved.

## Baseline

- Model: `Qwen/Qwen3-Coder-Next-FP8`
- vLLM image: `vllm/vllm-openai:v0.28.0-cu129-ubuntu2404`
- Single NVIDIA GPU / tensor parallel size 1
- Initial context length: 32768 tokens
- GPU memory utilization: 0.90
- FP8 KV cache
- Prefix caching enabled
- Chunked prefill enabled
- Automatic tool choice enabled
- Tool parser: `qwen3_coder`
- API bound only to host loopback: `127.0.0.1:8000`

The current baseline is intended for a single 96 GB NVIDIA RTX PRO 6000 Blackwell-class GPU. Tune memory/context settings only after the first successful model load.

## Deploy

Import this GitHub repository into the Docker/Compose manager and deploy it.

With Docker Compose directly:

```bash
docker compose up -d
```

On the first start, Docker pulls the vLLM image and vLLM downloads the Qwen model into the persistent `hf-cache` volume. This first startup therefore takes substantially longer than later container restarts.

Check status:

```bash
docker compose ps
```

Follow image/model loading:

```bash
docker compose logs -f vllm
```

Once healthy, the local OpenAI-compatible API is available on:

```text
http://127.0.0.1:8000
```

The loopback binding is deliberate. The deployment does not expose vLLM publicly by default.

## Persistent volumes

The Compose project creates two named volumes:

- `hf-cache` — downloaded Hugging Face model files
- `vllm-cache` — vLLM compile/runtime cache

Do not delete `hf-cache` during an ordinary redeploy if you want to avoid downloading the model again on the same host.

# AGENTS.md

**Tiny Local AI** — Run local LLM on MacBook A, access from MacBook B over LAN.

## Languages & Dependencies

- Python 3.10+ (`openai` package for client/router; `doctor.py`, `serve-dashboard.py` are stdlib-only)
- Bash (server management scripts)
- External: `llama-server` binary (from llama.cpp, in PATH or `scripts/`)

Managed with `uv`. Install deps: `uv sync` (or `uv add <pkg>`).

## Key Entrypoints (non-obvious)

| Entrypoint                  | What it does                                                                        |
| --------------------------- | ----------------------------------------------------------------------------------- |
| `swap` (root)               | Hot-swap models: `./swap status`, `./swap qwen`, `./swap glm`, `./swap --wait 120`  |
| `scripts/doctor.py`         | Hardware detection + model recommendations via canirun.ai data                      |
| `scripts/router.py`         | Smart routing — detects task type (coding vs general) and routes to the right model |
| `scripts/swap-model.py`     | Python version of `swap` (called by the `swap` wrapper script)                      |
| `scripts/download-model.sh` | Downloads GGUF models from HuggingFace                                              |

## Commands

```bash
# Server
./scripts/start-llm.sh qwen3-coder-next           # simple name
./scripts/start-llm.sh unsloth/GLM-4.7-Flash-GGUF  # HF ref (auto-downloads)
PORT=8080 ./scripts/start-llm.sh qwen              # custom port
./scripts/stop-llm.sh                               # kills tmux session

# Swap (uses hardcoded MODEL_CONFIGS in swap + swap-model.py)
./swap status
./swap qwen
./swap glm --wait 120 --verbose

# Download
./scripts/download-model.sh unsloth/Qwen3-Coder-Next-GGUF:Q4_K_M
./scripts/download-model.sh --list unsloth/Qwen3-Coder-Next-GGUF

# Client (uv run activates venv with openai)
uv run python scripts/llm-client.py -s "prompt"            # streaming
uv run python scripts/llm-client.py --system "You are..." "prompt"
uv run python scripts/llm-client.py --config -u http://host:8000/v1 -m modelname

# Dashboard
uv run python scripts/serve-dashboard.py
uv run python scripts/serve-dashboard.py -p 9000 -u http://192.168.1.100:8000

# Router (requires both servers running)
uv run python scripts/router.py "Write a function"    # auto-detect task type
uv run python scripts/router.py "Hello" --model glm   # force model
uv run python scripts/router.py "prompt" --stats      # routing stats

# Hardware / benchmark
uv run python scripts/doctor.py                             # hardware detection
uv run python scripts/benchmark.py --categories coding      # quick benchmark
./scripts/benchmark-startup.sh qwen3-coder-next 3           # startup timing

# Lint + format (via Astral toolchain)
uv run ruff check scripts/
uv run ruff check scripts/ --fix
uv run ruff format scripts/ --check
uv run ruff format scripts/
```

## Architecture Notes

- Server runs **inside tmux**, session name: `llm-server`. `stop-llm.sh` kills that session.
- Models are cached in `~/Library/Caches/llama.cpp` (default) or `$HF_HOME`.
- `scripts/start-llm.sh` detects RAM to auto-set context size (32K for ≥32GB, 16K for ≥16GB, 8K otherwise).
- `swap` at repo root is a Python script; it calls `swap-model.py` internally. Hardcoded model configs for `qwen` and `glm`.
- `data/hardware.json` and `data/models.json` are fetched from canirun.ai by `fetch-canirun-data.sh`.
- No test suite. Ruff config lives in `pyproject.toml` (`[tool.ruff]`).

## Environment Variables

| Var              | Default                      | Used by                      |
| ---------------- | ---------------------------- | ---------------------------- |
| `LLM_SERVER_URL` | —                            | `llm-client.py`, `router.py` |
| `LLM_MODEL`      | `qwen`                       | client scripts               |
| `MODELS_DIR`     | `~/models`                   | `start-llm.sh`               |
| `HF_HOME`        | `~/Library/Caches/llama.cpp` | model cache location         |
| `PORT`           | `8000`                       | `start-llm.sh`               |
| `HOST`           | `0.0.0.0`                    | `start-llm.sh`               |

## Bash Style Quirk

- Indent with **tabs**, not spaces (existing scripts use tabs).

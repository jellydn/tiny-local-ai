# Tiny Local AI

> Run local LLM on MacBook A, access from MacBook B over LAN

[![GitHub stars](https://img.shields.io/github/stars/jellydn/tiny-local-ai)](https://github.com/jellydn/tiny-local-ai/stargazers)
[![GitHub license](https://img.shields.io/github/license/jellydn/tiny-local-ai)](https://github.com/jellydn/tiny-local-ai/blob/main/LICENSE)

## Features

- 🚀 **Metal Acceleration** - GPU-offloaded inference on Apple Silicon
- 🌐 **LAN Access** - OpenAI-compatible API accessible from other machines
- 🖥️ **Dual-Mac Setup** - Server on MacBook A, client on MacBook B
- 📊 **Web Dashboard** - Monitor server status
- 🔧 **Auto Hardware Detection** - Automatically optimizes context size based on RAM
- 📦 **Model Agnostic** - Supports any GGUF model (Qwen3-Coder-Next, MiniMax-M2.5, etc.)

## Prerequisites

- **llama.cpp** with Metal support - [Build from source](https://github.com/ggerganov/llama.cpp) or download from [releases](https://github.com/ggerganov/llama.cpp/releases)
- **Python 3.10+** - For CLI client and dashboard
- **GGUF model** - Download from [Unsloth.ai](https://unsloth.ai/)

## Quick Start

### 1. Download llama.cpp

```bash
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make LLAMA_METAL=1
```

### 2. Download a Model

Get GGUF models from HuggingFace (Recommended):

```bash
# Get hardware-specific recommendations
./scripts/download-model.sh --suggest

# List all available quantizations for a model
./scripts/download-model.sh --list unsloth/Qwen3-Coder-Next-GGUF

# Download a specific quantization
./scripts/download-model.sh unsloth/Qwen3-Coder-Next-GGUF:Q4_K_M

# Download with extreme quantization (80B model on 32GB)
./scripts/download-model.sh unsloth/Qwen3-Coder-Next-GGUF:UD-IQ1_S
```

**Models available from Unsloth.ai:**

- [Qwen3-Coder-Next-80B](https://huggingface.co/unsloth/Qwen3-Coder-Next-GGUF) - Best for code generation
- [GLM-4.7-Flash](https://huggingface.co/unsloth/GLM-4.7-Flash-GGUF) - Balances performance and efficiency
- [MiniMax-M2.5](https://huggingface.co/unsloth/MiniMax-M2.5-GGUF) - Best reasoning, compact

**Recommended Models by Hardware:**

| Hardware          | Tier           | Model Size | Quant          | Context | Speed        |
| ----------------- | -------------- | ---------- | -------------- | ------- | ------------ |
| M1/M2/M3 Max 32GB | Best Quality   | 32B        | Q4_K_M         | 8K-16K  | 8-12 tok/sec |
| M1/M2/M3 Max 32GB | Extended CTX   | 14B        | Q4_K_M/Q5_K_M  | 16K-32K | 15-25 tok/s  |
| M1/M2/M3 Max 32GB | Advanced (NEW) | 80B        | UD-IQ1_S/TQ1_0 | 4K-8K   | 2-4 tok/sec  |
| M1/M2 Pro 16GB    | Best Balance   | 14B        | Q4_K_M         | 8K      | 12-20 tok/s  |
| M1/M2 Pro 16GB    | Larger Context | 14B        | Q4_K_S         | 16K     | 10-15 tok/s  |
| M1/M2 8GB         | Best Option    | 7B         | Q4_K_S         | 8K      | 15-25 tok/s  |

**New Discovery: 80B Models Now Viable! 🎉**

With extreme quantizations (1-2 bit), even large 80B models fit on 32GB:

- **UD-IQ1_S** (~21.5GB): 1-bit quantization, good quality at extreme compression
- **UD-TQ1_0** (~18.9GB): 1-bit, slightly smaller than IQ1_S
- **UD-IQ1_M** (~24.2GB): 2-bit, tight fit but higher quality

Example (Qwen3-Coder-Next-80B on M1 Max):

```bash
./scripts/download-model.sh unsloth/Qwen3-Coder-Next-GGUF:UD-IQ1_S
./scripts/start-llm.sh unsloth/Qwen3-Coder-Next-GGUF:UD-IQ1_S
```

**What to Avoid:**

- ❌ Q4_K_M with 80B models on 32GB (~48GB required)
- ❌ 70B-80B models with Q5_K_M or larger quantizations
- ✅ Use 32B-14B models for best quality/speed trade-off
- ✅ Use extreme quantizations (UD-IQ1_S) only if you need large model reasoning and can tolerate 2-4 tok/sec

#### Custom Cache Location

Set `HF_HOME` to change where models are cached (default: `~/Library/Caches/llama.cpp`):

```bash
export HF_HOME=/your/custom/path
./scripts/download-model.sh unsloth/Qwen3-Coder-Next-GGUF:Q4_K_M
```

### 3. Start Server (MacBook A)

```bash
# Basic usage
./scripts/start-llm.sh unsloth/Qwen3-Coder-Next-GGUF:UD-IQ1_S

# Or with custom model path
MODEL_NAME=my-model ./scripts/start-llm.sh
```

### 4. Use Client (MacBook B)

```bash
# Install client dependency
pip install openai

export LLM_SERVER_URL=http://192.168.1.x:8000/v1
# Send a prompt
python scripts/llm-client.py "Write a Python function to calculate fibonacci"

# Or with streaming
python scripts/llm-client.py -s "Tell me a story"
```

## Architecture

```
┌─────────────────────┐         ┌─────────────────────┐
│   MacBook A         │         │   MacBook B         │
│   (Server)          │   LAN   │   (Client)         │
│                     │         │                     │
│  ┌───────────────┐  │         │  ┌───────────────┐  │
│  │ llama-server	 │◄─┼─────────┼─►│ llm-client.py │  │
│  │ :8000/v1      │  │         │  │ or curl       │  │
│  │ Metal GPU     │  │         │  │               │  │
│  └───────────────┘  │         │  └───────────────┘  │
└─────────────────────┘         └─────────────────────┘
```

## Scripts

| Script                   | Description                                   |
| ------------------------ | --------------------------------------------- |
| `download-model.sh`      | Download GGUF models from HuggingFace         |
| `start-llm.sh`           | Start LLM server with auto hardware detection |
| `start-llm-router.sh`    | Auto-detect and start with optimal model      |
| `start-llm-optimized.sh` | Start with optimized parameters by model      |
| `stop-llm.sh`            | Stop the LLM server                           |
| `list-models.sh`         | List available cached models with sizes       |
| `llm-client.py`          | CLI client for interacting with the server    |
| `serve-dashboard.py`     | Web dashboard to monitor server status        |
| `doctor.py`              | Hardware detection & model recommendations    |
| `router.py`              | Smart routing CLI with task-type detection    |
| `swap-completion.bash`   | Bash shell completion for swap command        |
| `swap-completion.zsh`    | Zsh shell completion for swap command         |

## Hardware Doctor

Auto-detect hardware and get model recommendations:

```bash
python3 scripts/doctor.py
```

Output:

```
============================================================
  🔍 Tiny Local AI - Hardware Doctor
============================================================

============================================================
  DETECTED HARDWARE
============================================================
  Chip:                 Apple M1 Max
  CPU Cores:            10
  GPU Cores:            24
  RAM:                  32 GB
  RAM Available:        28 GB
  Metal Support:        ✅ Yes

============================================================
  RECOMMENDED MODELS
============================================================
  1. Qwen3-Coder-Next (20.0GB)
     Estimated: ~25 tok/sec | Best for: coding
  2. GLM-4.7-Flash (16.3GB)
     Estimated: ~41 tok/sec | Best for: chat, QA

============================================================
  SYSTEM CHECK
============================================================
  ✅ llama-server installed
  ✅ Model cache configured
```

## Smart Router

Automatically route prompts to optimal model based on task type:

```bash
# Auto-detect and route
python3 scripts/router.py "Write a Python function to fibonacci"

# Force specific model
python3 scripts/router.py "Hello" --model glm

# With streaming
python3 scripts/router.py "Tell me a story" --stream

# Show routing statistics
python3 scripts/router.py "prompt" --stats
```

### Task Detection

The router automatically detects:

- **Coding tasks**: Keywords like `function`, `class`, `debug`, `api`, etc.
- **General tasks**: Everything else

Routing logic:

- **Coding prompts** → Qwen3-Coder-Next (concise, structured)
- **General prompts** → GLM-4.7-Flash (fast, detailed)

### Dual Server Mode

For 64GB+ RAM, run both models simultaneously:

```bash
./scripts/start-dual-servers.sh
# Starts Qwen on port 8000, GLM on port 8001

# Then use router
python3 scripts/router.py "your prompt"
```

## Model Hot-Swap

Quickly switch between models on a single server:

```bash
# Check current status
./swap status

# Swap to Qwen
./swap qwen

# Swap to GLM
./swap glm

# Or use Python directly
python3 scripts/swap-model.py status
python3 scripts/swap-model.py qwen
python3 scripts/swap-model.py glm

# Swap with custom timeout (for slow loading)
./swap qwen --wait 120

# Verbose output
./swap glm --verbose
```

The hot-swap automatically:

1. Detects current model and server status
2. Validates server is running (with process-level fallback detection)
3. Stops old server gracefully
4. Starts new model with optimized parameters
5. Waits for server to be ready (with progress output)
6. Confirms success with new model name

### Robust Server Detection

The swap mechanism uses multi-level detection to reliably identify server status:

- **API Health Check**: Validates JSON response structure from `/health` endpoint
- **Retry Logic**: 3 attempts with 1-second backoff for slow API responses
- **Process-Level Fallback**: Uses `pgrep` to detect llama-server process when API isn't ready yet
- **Extended Timeout**: 90 seconds default (customizable with `--wait`)
- **Progress Feedback**: Shows "⏳ Starting..." status during model load

## Server Startup Patterns

The `start-llm.sh` script supports multiple ways to specify models with automatic discovery:

### Pattern 1: Simple Model Name (Case-Insensitive)

```bash
./scripts/start-llm.sh qwen3-coder-next
```

- Searches `~/models` first (for local GGUF files)
- Fallback to cache directory `~/Library/Caches/llama.cpp` (HuggingFace cache)
- Case-insensitive matching: `qwen3-coder-next` → `unsloth_Qwen3-Coder-Next-GGUF_UD-IQ1_S.gguf`
- Best for: Quick prototyping, aliases

### Pattern 2: HuggingFace Repository Reference

```bash
./scripts/start-llm.sh unsloth/Qwen3-Coder-Next-GGUF
```

- Auto-downloads if not cached (first run may take 10+ minutes)
- Uses latest quantization in cache, or downloads latest from HuggingFace
- Searches multiple cache locations automatically
- Best for: Reproducibility, HuggingFace integration

### Pattern 3: HuggingFace with Specific Quantization

```bash
./scripts/start-llm.sh unsloth/Qwen3-Coder-Next-GGUF:UD-IQ1_S
./scripts/start-llm.sh unsloth/GLM-4.7-Flash-GGUF:Q4_K_M
```

- Downloads specific quantization if not cached
- Format: `org/model:quantization`
- Best for: Precise control, benchmarking

### Pattern 4: Full File Path

```bash
./scripts/start-llm.sh /path/to/my-model.gguf
./scripts/start-llm.sh /Users/you/Downloads/custom-model.gguf
```

- Direct path to any GGUF file
- No searching or downloading
- Best for: Custom quantizations, external models

### Pattern 5: Router (Auto-Start)

```bash
# Single model with optimized defaults
./scripts/start-llm-router.sh

# Detects cached models and auto-selects best fit for hardware
# Creates single-server mode with quick startup
```

- Automatically detects available cached models
- Selects best match for your hardware
- Single model, optimized parameters
- Best for: One-command startup, minimal configuration

### Model Discovery Behavior

| Pattern     | Search Order      | Download | Auto-Find      |
| ----------- | ----------------- | -------- | -------------- |
| Simple name | `~/models`, cache | ❌ No    | ✅ Yes         |
| HF repo     | Cache, then HF    | ✅ Yes   | ✅ Yes         |
| HF + quant  | Cache, then HF    | ✅ Yes   | ✅ Yes (exact) |
| Full path   | Direct            | ❌ No    | ❌ No          |
| Router      | Cache             | ❌ No    | ✅ Yes         |

### Example Workflows

#### Workflow: Quick Start with Cached Model

```bash
# Start with simple name (fastest)
./scripts/start-llm.sh qwen3-coder-next

# Check status
./swap status

# Make requests
python scripts/llm-client.py "Write hello world in Python"
```

#### Workflow: Download and Start Specific Quantization

```bash
# Download specific quantization
./scripts/download-model.sh unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_XL

# Start with HF reference
./scripts/start-llm.sh unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_XL

# Swap to different model
./swap glm

# Check which model is running
./swap status
```

#### Workflow: Multi-Model Switching

```bash
# Initial startup with router
./scripts/start-llm-router.sh
# → Auto-selected Qwen from cache

# Swap to GLM
./swap glm

# Back to Qwen
./swap qwen

# Swap with extended timeout (slow loading)
./swap glm --wait 120

# Verbose output to see what's happening
./swap qwen --verbose
```

## Configuration

### Shell Completions

#### Bash Completion

```bash
# Add to ~/.bash_profile or ~/.bashrc
source /path/to/scripts/swap-completion.bash
```

Then you can use tab completion:

```bash
./swap <TAB>        # Shows: status qwen glm start stop help
./swap qwen <TAB>   # Shows: --wait --verbose --help
```

#### Zsh Completion

```bash
# Setup zsh completions
mkdir -p ~/.zsh/completions
ln -s /path/to/scripts/swap-completion.zsh ~/.zsh/completions/_swap

# Add to ~/.zshrc if not already there
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit && compinit
```

Then you can use tab completion with descriptions:

```bash
./swap <TAB>     # Shows all commands with descriptions
./swap qwen <TAB> # Shows flags for qwen command
```

### Environment Variables

```bash
# Server URL (on client)
export LLM_SERVER_URL=http://192.168.1.x:8000/v1

# Model name (default: qwen)
export LLM_MODEL=qwen

# Models directory for local GGUF files (default: ~/models)
export MODELS_DIR=~/models

# HuggingFace cache directory (default: ~/Library/Caches/llama.cpp)
export HF_HOME=~/custom-cache
```

### Save Default Config

```bash
python scripts/llm-client.py --config -u http://192.168.1.x:8000/v1 -m unsloth_Qwen3-Coder-Next-GGUF_UD-IQ1_S.gguf
```

## Usage Examples

### Server Management

```bash
# Start with local model (existing behavior)
./scripts/start-llm.sh qwen3-coder-next

# Start with HuggingFace repo reference (auto-downloads if needed)
./scripts/start-llm.sh unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_XL

# Start with custom port
PORT=8080 ./scripts/start-llm.sh qwen

# Start with HuggingFace using custom cache location
HF_HOME=/custom/cache ./scripts/start-llm.sh unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_XL

# Stop server
./scripts/stop-llm.sh
```

### CLI Client

```bash
export LLM_SERVER_URL=http://192.168.1.x:8000/v1
# Simple prompt
python scripts/llm-client.py "Hello, write a hello world in Rust"

# With system prompt
python scripts/llm-client.py --system "You are a code reviewer" "Review this function"

# Streaming response
python scripts/llm-client.py -s "Count to 10"

# Using curl directly
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### Web Dashboard

```bash
# Start dashboard (default port 8080)
python scripts/serve-dashboard.py

# Custom port
python scripts/serve-dashboard.py -p 9000

# Custom server URL
python scripts/serve-dashboard.py -u http://192.168.1.100:8000
```

## Network Setup

### 1. Find Server IP

```bash
# On server MacBook
ipconfig getifaddr en0
```

### 2. Open Firewall Port

```bash
# On server MacBook
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /path/to/llama-server
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unockapp /path/to/llama-server
```

### 3. Static IP (Optional)

Set a static IP on your server MacBook via System Settings > Network > Advanced > TCP/IP > Configure IPv4: Manually

## Performance

Expected performance on M1 Max 32GB:

- **Throughput**: 6-12 tokens/sec
- **Context**: Up to 32K tokens
- **Model**: Q4_K_M or Q5_K_M quantization recommended

## Security Notes

- This setup does NOT include authentication by default
- Only use on trusted local networks
- Consider adding nginx with basic auth for production use

## Related

- [my-ai-tools](https://github.com/jellydn/my-ai-tools) - My complete AI setup
- [ai-launcher](https://github.com/jellydn/ai-launcher) - CLI tool to switch between AI assistants
- [llama.cpp](https://github.com/ggerganov/llama.cpp) - GGML-based LLM inference
- [Unsloth](https://unsloth.ai/) - Fast fine-tuning and GGUF conversion

## Verification & Testing

All features have been tested and verified on **MacBook A - M1 Max 32GB**:

### ✅ Verified Functionality

- [x] **Model Download**: Qwen3-Coder-Next (80B) UD-IQ1_S successfully downloaded (21.5GB)
- [x] **Server Startup**: llama-server starts and loads model successfully
- [x] **GPU Acceleration**: Metal acceleration enabled, all layers offloaded to GPU
- [x] **Memory Usage**: 32.5GB RAM (full model loaded)
- [x] **Health Endpoint**: `/health` responds correctly
- [x] **Completions API**: `/v1/completions` generates correct responses (26-28 tok/sec)
- [x] **Chat API**: `/v1/chat/completions` works with messages and streaming
- [x] **Streaming**: SSE streaming works correctly
- [x] **Python Client**: `llm-client.py` works with and without streaming
- [x] **LAN Access**: Server accessible on `192.168.1.11:8000` from any machine
- [x] **Code Generation**: Generated code is syntactically correct and functional

### Test Examples

```bash
# API Health Check
curl http://localhost:8000/health
# {"status":"ok"}

# Chat Completion
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 50
  }'

# Python Client (with streaming)
python scripts/llm-client.py -s "Write a hello world function"

# From another Mac on LAN
export LLM_SERVER_URL=http://192.168.1.11:8000/v1
python scripts/llm-client.py "Your prompt here"
```

### Performance Benchmarks

Normalized benchmark (max_tokens=512) on M1 Max 32GB:

| Model            | Avg Response Time | Tokens/sec | Avg Tokens | Use Case     |
| ---------------- | ----------------- | ---------- | ---------- | ------------ |
| Qwen3-Coder-Next | 14.95s ± 6.54s    | 24.63      | 380        | Coding       |
| GLM-4.7-Flash    | 11.39s ± 2.94s    | 41.19      | 468        | General/Chat |

**Key Findings:**

- GLM is **23.8% faster per-task** (11.39s vs 14.95s)
- GLM is **67.2% faster per-token** (41.19 vs 24.63 tok/sec)
- Qwen generates **19% more concise** responses (380 vs 468 tokens)

Run your own benchmarks:

```bash
# Quick benchmark (5 prompts)
python3 scripts/benchmark.py --categories coding --skip-model glm

# Full benchmark (all prompts)
python3 scripts/benchmark.py --max-tokens 512

# Output JSON for analysis
python3 scripts/benchmark.py --output results.json
```

---

## 👤 Author

**Dung Huynh**

- Website: [productsway.com](https://productsway.com)
- YouTube: [IT Man Channel](https://www.youtube.com/@it-man)
- GitHub: [@jellydn](https://github.com/jellydn)

---

## ⭐ Show your support

Give a ⭐️ if this project helped you!

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/dunghd)

---

Made with ❤️ by [Dung Huynh](https://productsway.com)

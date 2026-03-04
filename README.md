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
- [Qwen2.5-Coder-32B](https://huggingface.co/unsloth/Qwen2.5-Coder-32B-GGUF) - Excellent coding + reasoning
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
./scripts/start-llm.sh qwen3-coder-next

# Or with custom model path
MODEL_NAME=my-model ./scripts/start-llm.sh
```

### 4. Use Client (MacBook B)

```bash
# Install client dependency
pip install openai

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
│  │ llama-server │◄─┼─────────┼─►│ llm-client.py │  │
│  │ :8000/v1     │  │         │  │ or curl       │  │
│  │ Metal GPU    │  │         │  │               │  │
│  └───────────────┘  │         │  └───────────────┘  │
└─────────────────────┘         └─────────────────────┘
```

## Scripts

| Script               | Description                                   |
| -------------------- | --------------------------------------------- |
| `download-model.sh`  | Download GGUF models from HuggingFace         |
| `start-llm.sh`       | Start LLM server with auto hardware detection |
| `stop-llm.sh`        | Stop the LLM server                           |
| `llm-client.py`      | CLI client for interacting with the server    |
| `serve-dashboard.py` | Web dashboard to monitor server status        |

## Configuration

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
python scripts/llm-client.py --config -u http://192.168.1.x:8000/v1 -m qwen
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

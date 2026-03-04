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

Get GGUF models from Unsloth.ai:

- [Qwen3-Coder-Next-80B](https://unsloth.ai/docs/models/qwen3-coder-next) - Best for code generation
- [MiniMax-M2.5](https://unsloth.ai/docs/models/minimax-m25) - Excellent reasoning

Save to `~/models/` directory:

```bash
mkdir -p ~/models/qwen
# Move your downloaded .gguf file to ~/models/qwen/
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

# Models directory (default: ~/models)
export MODELS_DIR=~/models
```

### Save Default Config

```bash
python scripts/llm-client.py --config -u http://192.168.1.x:8000/v1 -m qwen
```

## Usage Examples

### Server Management

```bash
# Start with specific model
./scripts/start-llm.sh qwen3-coder-next

# Start with custom port
PORT=8080 ./scripts/start-llm.sh qwen

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

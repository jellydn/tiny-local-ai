#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="${MODELS_DIR:-$HOME/models}"
TMUX_SESSION="llm-server"
LLAMA_SERVER="./llama-server"

MODEL_NAME="${1:-qwen3-coder-next}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8000}"

detect_ram() {
	local RAM
	RAM=$(sysctl -n hw.memsize 2>/dev/null || echo "34359738368")
	local RAM_GB=$((RAM / 1024 / 1024 / 1024))
	echo "$RAM_GB"
}

detect_context_size() {
	local ram_gb
	ram_gb=$(detect_ram)
	if [ "$ram_gb" -ge 32 ]; then
		echo "32768"
	elif [ "$ram_gb" -ge 16 ]; then
		echo "16384"
	else
		echo "8192"
	fi
}

find_model() {
	local model_name="$1"
	local search_dir="$MODELS_DIR"

	if [ -f "$model_name" ]; then
		echo "$model_name"
		return
	fi

	for ext in gguf GGUF; do
		if [ -f "$search_dir/$model_name.$ext" ]; then
			echo "$search_dir/$model_name.$ext"
			return
		fi

		if [ -f "$search_dir/${model_name}.$ext" ]; then
			echo "$search_dir/${model_name}.$ext"
			return
		fi
	done

	local found
	found=$(find "$search_dir" -maxdepth 2 -name "*${model_name}*" -name "*.gguf" 2>/dev/null | head -1)
	if [ -n "$found" ]; then
		echo "$found"
		return
	fi

	echo ""
}

resolve_hf_model() {
	local model_ref="$1"
	local cache_dir="${HF_HOME:-$HOME/Library/Caches/llama.cpp}"

	local repo="${model_ref%%:*}"
	local quant="${model_ref##*:}"

	if [ "$quant" = "$repo" ]; then
		quant="Q4_K_M"
	fi

	local repo_slug="${repo//\//_}"

	local found
	found=$(ls "$cache_dir" 2>/dev/null | grep "^${repo_slug}_.*${quant}\.gguf$" | head -1)
	if [ -n "$found" ]; then
		echo "$cache_dir/$found"
		return
	fi

	echo ""
}

check_llama_server() {
	if command -v llama-server &>/dev/null; then
		echo "llama-server"
		return
	fi

	local local_binary
	local_binary=$(find "$SCRIPT_DIR" -name "llama-server" -type f 2>/dev/null | head -1)
	if [ -n "$local_binary" ]; then
		echo "$local_binary"
		return
	fi

	echo ""
}

echo "=== Tiny Local AI Server ==="
echo "Model: $MODEL_NAME"
echo "Host: $HOST:$PORT"

ram_gb=$(detect_ram)
echo "RAM: ${ram_gb}GB"

CTX_SIZE=$(detect_context_size)
echo "Context: $CTX_SIZE"

CACHE_DIR="${HF_HOME:-$HOME/Library/Caches/llama.cpp}"

if [[ "$MODEL_NAME" == *"/"* ]]; then
	echo "Model: $MODEL_NAME (HuggingFace)"
	MODEL_PATH=$(resolve_hf_model "$MODEL_NAME")
	HF_MODE=true

	if [ -z "$MODEL_PATH" ]; then
		echo "Model not found in cache: $MODEL_NAME"
		echo "Cache dir: $CACHE_DIR"
		echo ""
		echo "Download first with:"
		echo "  ./download-model.sh $MODEL_NAME"
		exit 1
	fi
else
	MODEL_PATH=$(find_model "$MODEL_NAME")
	HF_MODE=false

	if [ -z "$MODEL_PATH" ]; then
		echo "Error: Model not found: $MODEL_NAME"
		echo "Searched in: $MODELS_DIR"
		echo ""
		echo "Available models:"
		ls -la "$MODELS_DIR" 2>/dev/null || echo "  (directory empty)"
		exit 1
	fi
fi

check_model_size() {
	local model_path="$1"

	if [ ! -f "$model_path" ]; then
		return 0
	fi

	local model_size_mb
	model_size_mb=$(stat -f%z "$model_path" 2>/dev/null || stat -c%s "$model_path" 2>/dev/null)
	model_size_mb=$((model_size_mb / 1024 / 1024))

	local ram_gb=$(detect_ram)
	local usable_mb=$((ram_gb * 1024 * 70 / 100))

	if [ "$model_size_mb" -gt "$usable_mb" ]; then
		echo ""
		echo "⚠️  WARNING: Model size exceeds ~70% of system RAM"
		echo ""
		echo "Model:     ${model_size_mb} MB"
		echo "Safe max:  ~${usable_mb} MB"
		echo ""
		echo "This model may cause OOM errors. Recommended alternatives:"
		echo "  - Use smaller quantization: Q4_K_S instead of Q4_K_M"
		echo "  - Use smaller model: 14B-32B instead of 70B+"
		echo "  - Reduce context: --ctx-size 4096"
		echo ""
		echo "Get recommendations: ./download-model.sh --suggest"
		echo ""
		read -p "Continue anyway? (y/N) " -n 1 -r
		echo
		if [[ ! $REPLY =~ ^[Yy]$ ]]; then
			exit 1
		fi
	fi
}

echo "Model path: $MODEL_PATH"
echo "Cache dir: $CACHE_DIR"

check_model_size "$MODEL_PATH"

LLAMA_BIN=$(check_llama_server)
if [ -z "$LLAMA_BIN" ]; then
	echo "Error: llama-server not found"
	echo "Please install llama.cpp or place llama-server in scripts/"
	exit 1
fi

echo "Using: $LLAMA_BIN"

if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
	echo "Stopping existing session..."
	tmux kill-session -t "$TMUX_SESSION"
	sleep 1
fi

echo "Starting server in tmux..."

if [ "$HF_MODE" = true ]; then
	tmux new-session -d -s "$TMUX_SESSION" \
		"$LLAMA_BIN" \
		-hf "$MODEL_NAME" \
		--host "$HOST" \
		--port "$PORT" \
		--ctx-size "$CTX_SIZE" \
		--n-gpu-layers 999 \
		--log-disable
else
	tmux new-session -d -s "$TMUX_SESSION" \
		"$LLAMA_BIN" \
		-m "$MODEL_PATH" \
		--host "$HOST" \
		--port "$PORT" \
		--ctx-size "$CTX_SIZE" \
		--n-gpu-layers 999 \
		--log-disable
fi

sleep 2

if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
	echo ""
	echo "=== Server Started ==="
	echo "URL: http://$HOST:$PORT/v1"
	echo "API: OpenAI-compatible"
	echo ""
	echo "View logs: tmux attach -t $TMUX_SESSION"
	echo "Stop: ./stop-llm.sh"
else
	echo "Error: Failed to start server"
	exit 1
fi

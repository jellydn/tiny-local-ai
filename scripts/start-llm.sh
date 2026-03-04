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

MODEL_PATH=$(find_model "$MODEL_NAME")
if [ -z "$MODEL_PATH" ]; then
	echo "Error: Model not found: $MODEL_NAME"
	echo "Searched in: $MODELS_DIR"
	echo ""
	echo "Available models:"
	ls -la "$MODELS_DIR" 2>/dev/null || echo "  (directory empty)"
	exit 1
fi

echo "Model path: $MODEL_PATH"

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

tmux new-session -d -s "$TMUX_SESSION" \
	"$LLAMA_BIN" \
	-m "$MODEL_PATH" \
	--host "$HOST" \
	--port "$PORT" \
	--ctx-size "$CTX_SIZE" \
	--n-gpu-layers 999 \
	--log-disable

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

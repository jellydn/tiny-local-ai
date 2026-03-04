#!/usr/bin/env bash
# Enhanced start-llm.sh with optimized parameters for GLM and Qwen
# Applies parameter tuning recommendations from unsloth guide (Jan 2026)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="${MODELS_DIR:-$HOME/Library/Caches/llama.cpp}"
TMUX_SESSION="llm-server"

MODEL_NAME="${1:-qwen3-coder-next}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8000}"
PROFILE="${PROFILE:-general}" # general or tool-calling

# Detect RAM and set context size
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

# Resolve model file from cache
resolve_model() {
	local model_name="$1"
	local cache_dir="$MODELS_DIR"

	if [ -f "$model_name" ]; then
		echo "$model_name"
		return
	fi

	local found
	found=$(find "$cache_dir" -maxdepth 1 -name "*${model_name}*" -name "*.gguf" 2>/dev/null | head -1)
	if [ -n "$found" ]; then
		echo "$found"
		return
	fi

	echo ""
}

# Main
CTX_SIZE=$(detect_context_size)
MODEL_PATH=$(resolve_model "$MODEL_NAME")

if [ -z "$MODEL_PATH" ]; then
	echo "Error: Model not found for '$MODEL_NAME'"
	echo ""
	echo "Available cached models:"
	ls -lh "$MODELS_DIR"/*.gguf 2>/dev/null | awk '{print "  " $NF}' || echo "  (none found)"
	echo ""
	echo "Download with: ./scripts/download-model.sh --suggest"
	exit 1
fi

MODEL_FILE=$(basename "$MODEL_PATH")

echo "=== Starting LLM Server (Optimized) ==="
echo ""
echo "Model: $MODEL_FILE"
echo "Path: $MODEL_PATH"
echo "Size: $(du -h "$MODEL_PATH" | cut -f1)"
echo ""
echo "Configuration:"
echo "  Host: $HOST"
echo "  Port: $PORT"
echo "  Context: $CTX_SIZE tokens"
echo "  GPU Layers: All (-1)"
echo ""

# Build command with model-specific optimizations
if [[ "$MODEL_FILE" =~ "GLM" ]]; then
	echo "[GLM] Applying GLM-4.7-Flash optimizations..."
	if [ "$PROFILE" = "tool-calling" ]; then
		echo "   Profile: Tool-Calling (focused, deterministic)"
		echo "   Temperature: 0.7"
		echo "   Top-P: 1.0 (disable filtering)"
		echo "   Min-P: 0.01"
		SERVER_CMD="llama-server -m \"$MODEL_PATH\" --host $HOST --port $PORT --ctx-size $CTX_SIZE --n-gpu-layers -1 --temp 0.7 --top-p 1.0 --min-p 0.01 --repeat-penalty 1.0"
	else
		echo "   Profile: General Use (creative, verbose)"
		echo "   Temperature: 1.0"
		echo "   Top-P: 0.95"
		echo "   Min-P: 0.01"
		SERVER_CMD="llama-server -m \"$MODEL_PATH\" --host $HOST --port $PORT --ctx-size $CTX_SIZE --n-gpu-layers -1 --temp 1.0 --top-p 0.95 --min-p 0.01 --repeat-penalty 1.0"
	fi
elif [[ "$MODEL_FILE" =~ "Qwen" ]]; then
	echo "[QWEN] Applying Qwen3-Coder-Next optimizations..."
	echo "   Profile: Coding (focused, concise)"
	echo "   Temperature: 0.7"
	echo "   Repeat-penalty: 1.0 (disabled)"
	SERVER_CMD="llama-server -m \"$MODEL_PATH\" --host $HOST --port $PORT --ctx-size $CTX_SIZE --n-gpu-layers -1 --temp 0.7 --repeat-penalty 1.0"
else
	echo "[INFO] Using generic parameters"
	SERVER_CMD="llama-server -m \"$MODEL_PATH\" --host $HOST --port $PORT --ctx-size $CTX_SIZE --n-gpu-layers -1"
fi

echo ""
echo "Command:"
echo "  $SERVER_CMD"
echo ""

# Stop existing session if running
if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
	echo "Stopping existing tmux session..."
	tmux kill-session -t "$TMUX_SESSION"
	sleep 1
fi

# Start in tmux if available
if command -v tmux &>/dev/null; then
	echo "Starting in tmux..."
	tmux new-session -d -s "$TMUX_SESSION" "sh" "-c" "$SERVER_CMD"
	sleep 3

	if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
		echo "[OK] Server started successfully!"
		echo ""
		echo "Access:"
		echo "  URL: http://$HOST:$PORT/v1"
		echo "  API: OpenAI-compatible"
		echo ""
		echo "Commands:"
		echo "  View logs:    tmux attach -t $TMUX_SESSION"
		echo "  Stop server:  ./scripts/stop-llm.sh"
		exit 0
	fi
fi

# Fallback: background process
echo "Starting in background..."
LOG_FILE="/tmp/llm-server-$PORT.log"
eval "$SERVER_CMD" >"$LOG_FILE" 2>&1 &
PID=$!

sleep 2
if kill -0 $PID 2>/dev/null; then
	echo "[OK] Server started (PID: $PID)"
	echo ""
	echo "Access: http://$HOST:$PORT/v1"
	echo "Logs: $LOG_FILE"
	exit 0
else
	echo "[ERROR] Server failed to start"
	cat "$LOG_FILE"
	exit 1
fi

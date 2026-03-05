#!/usr/bin/env bash
set -e
set -u

echo "=== Tiny Local AI - Single Server Mode ==="
echo "Note: llama.cpp router mode not available in this version."
echo "Use ./swap qwen or ./swap glm to switch models."
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_CACHE="$HOME/Library/Caches/llama.cpp"

DEFAULT_MODEL="${1:-qwen}"

case "$DEFAULT_MODEL" in
qwen)
	MODEL_PATH="$MODELS_CACHE/unsloth_Qwen3-Coder-Next-GGUF_UD-IQ1_S.gguf"
	MODEL_NAME="Qwen3-Coder-Next (IQ1_S, 80B)"
	TEMP_ARGS="--temp 0.7 --repeat-penalty 1.0"
	;;
glm)
	MODEL_PATH="$MODELS_CACHE/unsloth_GLM-4.7-Flash-GGUF_UD-Q4_K_XL.gguf"
	MODEL_NAME="GLM-4.7-Flash (Q4_K_XL, 30B)"
	TEMP_ARGS="--temp 0.7 --top-p 1.0 --min-p 0.01"
	;;
*)
	echo "Error: Unknown model '$DEFAULT_MODEL'"
	echo "Usage: $0 [qwen|glm]"
	exit 1
	;;
esac

if [ ! -f "$MODEL_PATH" ]; then
	echo "Error: Model not found at $MODEL_PATH"
	exit 1
fi

PORT="${PORT:-8000}"
GPU_LAYERS="${GPU_LAYERS:--1}"
CTX_SIZE="${CTX_SIZE:-32768}"

echo "Configuration:"
echo "  Model: $MODEL_NAME"
echo "  Port: $PORT"
echo "  GPU Layers: $GPU_LAYERS"
echo "  Context Size: $CTX_SIZE"
echo

pkill -f "llama-server" 2>/dev/null || true
sleep 1

echo "Starting server..."
echo "  Command: llama-server -m $MODEL_PATH ..."

llama-server \
	-m "$MODEL_PATH" \
	--host 0.0.0.0 \
	--port "$PORT" \
	--ctx-size "$CTX_SIZE" \
	--n-gpu-layers "$GPU_LAYERS" \
	$TEMP_ARGS &

echo "Waiting for server to start..."

for i in {1..30}; do
	if curl -s "http://localhost:$PORT/v1/models" | grep -q "object"; then
		echo "✓ Server is ready!"
		echo
		echo "Available at:"
		echo "  URL: http://localhost:$PORT/v1"
		echo "  Model: $MODEL_NAME"
		echo
		echo "To switch models:"
		echo "  ./swap qwen   # Switch to Qwen"
		echo "  ./swap glm    # Switch to GLM"
		echo "  ./swap status # Check current model"
		exit 0
	fi
	echo "Waiting... ($i/30)"
	sleep 2
done

echo "Error: Server failed to start"
exit 1

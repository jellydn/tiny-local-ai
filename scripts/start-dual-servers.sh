#!/usr/bin/env bash
set -e
set -u

echo "=== Tiny Local AI - Dual Server Mode ==="
echo "Starting two llama-server instances..."
echo

MODELS_CACHE="$HOME/Library/Caches/llama.cpp"

QWEN_MODEL="$MODELS_CACHE/unsloth_Qwen3-Coder-Next-GGUF_UD-IQ1_S.gguf"
GLM_MODEL="$MODELS_CACHE/unsloth_GLM-4.7-Flash-GGUF_UD-Q4_K_XL.gguf"

QWEN_PORT="${QWEN_PORT:-8000}"
GLM_PORT="${GLM_PORT:-8001}"
GPU_LAYERS="${GPU_LAYERS:--1}"
CTX_SIZE="${CTX_SIZE:-32768}"

echo "Configuration:"
echo "  Qwen Port: $QWEN_PORT"
echo "  GLM Port: $GLM_PORT"
echo "  GPU Layers: $GPU_LAYERS"
echo "  Context Size: $CTX_SIZE"
echo

pkill -f "llama-server" 2>/dev/null || true
sleep 2

echo "Starting Qwen server on port $QWEN_PORT..."
nohup llama-server \
	-m "$QWEN_MODEL" \
	--host 127.0.0.1 \
	--port "$QWEN_PORT" \
	--ctx-size "$CTX_SIZE" \
	--n-gpu-layers "$GPU_LAYERS" \
	--temp 0.7 \
	--repeat-penalty 1.0 \
	>qwen-server.log 2>&1 &
QWEN_PID=$!

echo "Starting GLM server on port $GLM_PORT..."
nohup llama-server \
	-m "$GLM_MODEL" \
	--host 127.0.0.1 \
	--port "$GLM_PORT" \
	--ctx-size "$CTX_SIZE" \
	--n-gpu-layers "$GPU_LAYERS" \
	--temp 0.7 \
	--top-p 1.0 \
	--min-p 0.01 \
	>glm-server.log 2>&1 &
GLM_PID=$!

echo "Waiting for servers to start..."

for i in {1..60}; do
	QWEN_READY=0
	GLM_READY=0

	if curl -s "http://localhost:$QWEN_PORT/v1/models" 2>/dev/null | grep -q "object"; then
		QWEN_READY=1
	fi

	if curl -s "http://localhost:$GLM_PORT/v1/models" 2>/dev/null | grep -q "object"; then
		GLM_READY=1
	fi

	if [ $QWEN_READY -eq 1 ] && [ $GLM_READY -eq 1 ]; then
		echo "✓ Both servers are ready!"
		echo
		echo "Server Endpoints:"
		echo "  Qwen: http://localhost:$QWEN_PORT/v1"
		echo "  GLM:  http://localhost:$GLM_PORT/v1"
		echo
		echo "To use with router:"
		echo "  python3 scripts/router.py 'your prompt'"
		echo
		echo "To use directly:"
		echo "  curl -X POST http://localhost:$QWEN_PORT/v1/chat/completions \\"
		echo "    -H 'Content-Type: application/json' \\"
		echo "    -d '{\"model\": \"qwen\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello\"}]}'"
		exit 0
	fi

	echo "Waiting... Qwen: $QWEN_READY/1 | GLM: $GLM_READY/1 ($i/60)"
	sleep 3
done

echo "Warning: One or more servers failed to start"
echo "Check logs: qwen-server.log, glm-server.log"
exit 1

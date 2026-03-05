#!/usr/bin/env bash
set -e
set -u

echo "=== Tiny Local AI - Router Mode ==="
echo "Starting llama-server with model router..."
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_CACHE="$HOME/Library/Caches/llama.cpp"

QWEN_MODEL="$MODELS_CACHE/unsloth_Qwen3-Coder-Next-GGUF_UD-IQ1_S.gguf"
GLM_MODEL="$MODELS_CACHE/unsloth_GLM-4.7-Flash-GGUF_UD-Q4_K_XL.gguf"

if [ ! -f "$QWEN_MODEL" ]; then
	echo "Error: Qwen model not found at $QWEN_MODEL"
	exit 1
fi

if [ ! -f "$GLM_MODEL" ]; then
	echo "Error: GLM model not found at $GLM_MODEL"
	exit 1
fi

PORT="${PORT:-8000}"
GPU_LAYERS="${GPU_LAYERS:--1}"
CTX_SIZE="${CTX_SIZE:-32768}"

echo "Configuration:"
echo "  Port: $PORT"
echo "  GPU Layers: $GPU_LAYERS"
echo "  Context Size: $CTX_SIZE"
echo

cat >/tmp/llama-models.ini <<EOF
[defaults]
context_size = $CTX_SIZE
gpu_layers = $GPU_LAYERS

[qwen]
model = $QWEN_MODEL
model_alias = qwen
temperature = 0.7
repeat_penalty = 1.0

[glm]
model = $GLM_MODEL
model_alias = glm
temperature = 0.7
top_p = 1.0
min_p = 0.01
EOF

echo "Model configuration:"
cat /tmp/llama-models.ini
echo

pkill -f "llama-server" 2>/dev/null || true
sleep 1

echo "Starting llama-server in router mode..."
echo "  Command: llama-server --models-preset /tmp/llama-models.ini --port $PORT"
echo

llama-server \
	--models-preset /tmp/llama-models.ini \
	--host 0.0.0.0 \
	--port "$PORT" \
	--sleep-idle-seconds 300 &

echo "Waiting for server to start..."
sleep 10

for i in {1..30}; do
	if curl -s "http://localhost:$PORT/v1/models" | grep -q "object"; then
		echo "✓ Server is ready!"
		echo
		echo "Available at:"
		echo "  URL: http://localhost:$PORT/v1"
		echo "  Models: qwen, glm"
		echo
		echo "To use specific model:"
		echo "  curl -X POST http://localhost:$PORT/v1/chat/completions \\"
		echo "    -H 'Content-Type: application/json' \\"
		echo "    -d '{\"model\": \"qwen\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello\"}]}'"
		echo
		echo "To route automatically:"
		echo "  python3 scripts/router.py 'your prompt'"
		exit 0
	fi
	echo "Waiting... ($i/30)"
	sleep 2
done

echo "Error: Server failed to start"
exit 1

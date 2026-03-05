#!/usr/bin/env bash
set -e
set -u

echo "=== Tiny Local AI - Single Server Mode ==="
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_CACHE="$HOME/Library/Caches/llama.cpp"

# Define available models and their metadata
get_model_config() {
	local model=$1
	case "$model" in
	qwen)
		echo "path:$MODELS_CACHE/unsloth_Qwen3-Coder-Next-GGUF_UD-IQ1_S.gguf"
		echo "name:Qwen3-Coder-Next (IQ1_S, 80B)"
		echo "args:--temp 0.7 --repeat-penalty 1.0"
		;;
	glm)
		echo "path:$MODELS_CACHE/unsloth_GLM-4.7-Flash-GGUF_UD-Q4_K_XL.gguf"
		echo "name:GLM-4.7-Flash (Q4_K_XL, 30B)"
		echo "args:--temp 0.7 --top-p 1.0 --min-p 0.01"
		;;
	esac
}

# Get available models
declare -a AVAILABLE_MODELS
for model in qwen glm; do
	path=$(get_model_config "$model" | grep "^path:" | cut -d: -f2-)
	if [ -f "$path" ]; then
		AVAILABLE_MODELS+=("$model")
	fi
done

# Determine which model to use
if [ $# -gt 0 ]; then
	# User specified model
	SELECTED_MODEL="$1"
	path=$(get_model_config "$SELECTED_MODEL" | grep "^path:" | cut -d: -f2-)
	if [ ! -f "$path" ]; then
		echo "Error: Model '$SELECTED_MODEL' not found in cache"
		echo "Available models: ${AVAILABLE_MODELS[*]}"
		exit 1
	fi
elif [ ${#AVAILABLE_MODELS[@]} -eq 0 ]; then
	# No models found
	echo "Error: No models found in cache: $MODELS_CACHE"
	echo "Download a model first:"
	echo "  ./scripts/download-model.sh unsloth/Qwen3-Coder-Next-GGUF:UD-IQ1_S"
	exit 1
elif [ ${#AVAILABLE_MODELS[@]} -eq 1 ]; then
	# Only one model available
	SELECTED_MODEL="${AVAILABLE_MODELS[0]}"
	echo "Found 1 model: $SELECTED_MODEL"
	echo
else
	# Multiple models available - ask user
	echo "Multiple models found. Which would you like to start?"
	echo
	for i in "${!AVAILABLE_MODELS[@]}"; do
		idx=$((i + 1))
		model="${AVAILABLE_MODELS[$i]}"
		config_output=$(get_model_config "$model")
		path=$(echo "$config_output" | grep "^path:" | cut -d: -f2-)
		name=$(echo "$config_output" | grep "^name:" | cut -d: -f2-)
		size=$(stat -f%z "$path" 2>/dev/null | awk '{printf "%.1fGB", $1 / 1024 / 1024 / 1024}')
		printf "  %d) %s (%s) %s\n" "$idx" "$model" "$name" "$size"
	done
	echo
	read -p "Select model (1-${#AVAILABLE_MODELS[@]}): " choice

	if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#AVAILABLE_MODELS[@]} ]; then
		echo "Invalid choice"
		exit 1
	fi

	SELECTED_MODEL="${AVAILABLE_MODELS[$((choice - 1))]}"
fi

# Get config for selected model
config_output=$(get_model_config "$SELECTED_MODEL")
MODEL_PATH=$(echo "$config_output" | grep "^path:" | cut -d: -f2-)
MODEL_NAME=$(echo "$config_output" | grep "^name:" | cut -d: -f2-)
TEMP_ARGS_VALUE=$(echo "$config_output" | grep "^args:" | cut -d: -f2-)

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
	$TEMP_ARGS_VALUE &

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

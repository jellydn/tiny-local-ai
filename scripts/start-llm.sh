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
	local cache_dir="${HF_HOME:-$HOME/Library/Caches/llama.cpp}"

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
	# Case-insensitive search in MODELS_DIR
	found=$(find "$search_dir" -maxdepth 2 -iname "*${model_name}*" -name "*.gguf" 2>/dev/null | head -1)
	if [ -n "$found" ]; then
		echo "$found"
		return
	fi

	# Case-insensitive fallback: Check cache directory for models matching the name
	found=$(find "$cache_dir" -maxdepth 1 -iname "*${model_name}*" -name "*.gguf" 2>/dev/null | head -1)
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
		quant="" # No quantization specified, search without it
	fi

	local repo_slug="${repo//\//_}"

	local found

	# Try exact slug + quant match first
	if [ -n "$quant" ]; then
		found=$(ls "$cache_dir" 2>/dev/null | grep "^${repo_slug}_.*${quant}\.gguf$" | head -1)
		if [ -n "$found" ]; then
			echo "$cache_dir/$found"
			return
		fi
	fi

	# Fallback: Try case-insensitive fuzzy match in cache directory
	local search_term=$(echo "$repo" | sed 's/\//-/g')
	if [ -n "$quant" ]; then
		found=$(find "$cache_dir" -maxdepth 1 -iname "*${search_term}*${quant}*" -name "*.gguf" 2>/dev/null | head -1)
	else
		found=$(find "$cache_dir" -maxdepth 1 -iname "*${search_term}*" -name "*.gguf" 2>/dev/null | head -1)
	fi
	if [ -n "$found" ]; then
		echo "$found"
		return
	fi

	# Last resort: Try just the model name
	local model_name=$(echo "$repo" | awk -F'/' '{print $NF}')
	if [ -n "$quant" ]; then
		found=$(find "$cache_dir" -maxdepth 1 -iname "*${model_name}*${quant}*" -name "*.gguf" 2>/dev/null | head -1)
	else
		found=$(find "$cache_dir" -maxdepth 1 -iname "*${model_name}*" -name "*.gguf" 2>/dev/null | head -1)
	fi
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
		echo ""
		echo "Searched in:"
		echo "  - $MODELS_DIR"
		echo "  - $CACHE_DIR"
		echo ""
		echo "Available models:"
		ls -1 "$MODELS_DIR" 2>/dev/null | grep -i ".gguf$" || true
		ls -1 "$CACHE_DIR" 2>/dev/null | grep -i ".gguf$" | head -5 || true
		echo ""
		echo "Options:"
		echo "  1. Download: ./download-model.sh $MODEL_NAME"
		echo "  2. Use full path: ./scripts/start-llm.sh /path/to/model.gguf"
		echo "  3. Use HuggingFace ref: ./scripts/start-llm.sh unsloth/Qwen3-Coder-Next-GGUF:UD-IQ1_S"
		exit 1
	fi
fi

check_model_size() {
	local model_path="$1"

	if [ ! -f "$model_path" ]; then
		return 0
	fi

	local model_size_bytes
	model_size_bytes=$(stat -f%z "$model_path" 2>/dev/null || stat -c%s "$model_path" 2>/dev/null)
	local model_size_mb=$((model_size_bytes / 1024 / 1024))
	local model_size_gb=$(echo "scale=1; $model_size_mb / 1024" | bc 2>/dev/null || echo "?")

	local ram_gb=$(detect_ram)
	local usable_mb=$((ram_gb * 1024 * 70 / 100))

	# Extract quantization from filename
	local filename=$(basename "$model_path")
	local quant=$(echo "$filename" | grep -oE '_(Q[0-9]_K_[SM]|IQ[0-9]_[SM]|TQ[0-9]_[0-9])' || echo "Unknown")

	# Determine if this is a large model
	local is_large=false
	if [[ $filename == *"Qwen3-Coder-Next"* ]] || [[ $filename == *"80B"* ]]; then
		is_large=true
	fi

	# Different thresholds based on model size
	local threshold_mb=$usable_mb
	local warning=false
	local critical=false

	if [ "$model_size_mb" -gt $((ram_gb * 1024 * 90 / 100)) ]; then
		critical=true
		warning=true
	elif [ "$model_size_mb" -gt $((ram_gb * 1024 * 75 / 100)) ]; then
		warning=true
	fi

	if [ "$warning" = true ]; then
		echo ""
		if [ "$critical" = true ]; then
			echo "🚨 CRITICAL: Model size may cause Out-Of-Memory errors"
		else
			echo "⚠️  WARNING: Model size is substantial (~${model_size_gb}GB)"
		fi
		echo ""
		echo "   Model:          ${model_size_gb}GB (${model_size_mb} MB)"
		echo "   RAM available:  ${ram_gb}GB"
		echo "   Quantization:   ${quant}"
		echo ""

		if [ "$critical" = true ]; then
			echo "   This model will likely exceed available memory!"
			echo ""
			echo "   Recommended fixes:"
			if [ "$is_large" = true ]; then
				echo "     • Use extreme quantization: UD-IQ1_S (vs current)"
				echo "     • Use smaller model: 32B or 14B instead of 80B"
				echo "     • Wait for 64GB+ RAM system"
			else
				echo "     • Use smaller quantization: Q4_K_S instead of Q4_K_M"
				echo "     • Use smaller model: 14B instead of 32B+"
				echo "     • Reduce context: --ctx-size 4096"
			fi
		else
			echo "   This should work but may be slow. Options to improve:"
			echo "     • Use lighter quantization to free up memory"
			echo "     • Close other applications to free RAM"
			echo "     • Reduce context window size"
		fi

		echo ""
		echo "   Get model recommendations: ./scripts/list-models.sh"
		echo ""

		if [ "$critical" = true ]; then
			read -p "   ⚠️  Continue anyway? (y/N) " -n 1 -r
		else
			read -p "   Continue? (Y/n) " -n 1 -r
		fi
		echo
		if [ "$critical" = true ]; then
			if [[ ! $REPLY =~ ^[Yy]$ ]]; then
				echo "   Aborted."
				exit 1
			fi
		else
			if [[ $REPLY =~ ^[Nn]$ ]]; then
				echo "   Aborted."
				exit 1
			fi
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

# Build the server command as a single string
SERVER_CMD="$LLAMA_BIN -m \"$MODEL_PATH\" --host $HOST --port $PORT --ctx-size $CTX_SIZE --n-gpu-layers 999 --log-disable"

# Try to start in tmux
if command -v tmux &>/dev/null; then
	# Use shell -c to ensure proper argument parsing in tmux
	tmux new-session -d -s "$TMUX_SESSION" "sh" "-c" "$SERVER_CMD" 2>/dev/null
	sleep 2

	if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
		echo ""
		echo "=== Server Started (in tmux) ==="
		echo "URL: http://$HOST:$PORT/v1"
		echo "API: OpenAI-compatible"
		echo ""
		echo "View logs: tmux attach -t $TMUX_SESSION"
		echo "Stop: ./stop-llm.sh"
		exit 0
	fi
fi

# Fallback: Start server in background directly
echo ""
echo "=== Starting server in background (no tmux) ==="
echo "URL: http://$HOST:$PORT/v1"
echo "API: OpenAI-compatible"
echo ""
echo "Logs will appear below. Press Ctrl+C to stop (server continues running)"
echo ""

# Start server in background, redirect output to a log file
LOG_FILE="/tmp/llm-server-$PORT.log"
eval "$SERVER_CMD" >"$LOG_FILE" 2>&1 &
SERVER_PID=$!

# Give server time to initialize
sleep 3

# Check if server is still running
if kill -0 $SERVER_PID 2>/dev/null; then
	echo "Server PID: $SERVER_PID"
	echo "Logs: $LOG_FILE"
	echo ""
	echo "To stop: kill $SERVER_PID"
	exit 0
else
	echo "Error: Server failed to start"
	echo "Logs:"
	cat "$LOG_FILE" 2>/dev/null || echo "(no logs)"
	exit 1
fi

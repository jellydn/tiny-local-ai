#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${HF_HOME:-$HOME/Library/Caches/llama.cpp}"

usage() {
	echo "Usage: $0 <repo>[:<quant>] [--cache-dir <path>]"
	echo ""
	echo "Arguments:"
	echo "  repo              HuggingFace repo (e.g., unsloth/Qwen3-Coder-Next-GGUF)"
	echo "  quant             Quantization suffix (e.g., UD-Q4_K_XL, Q4_K_M)"
	echo ""
	echo "Options:"
	echo "  --cache-dir <path>  Custom cache directory (default: ~/Library/Caches/llama.cpp)"
	echo "  -h, --help          Show this help message"
	echo ""
	echo "Examples:"
	echo "  $0 unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_XL"
	echo "  HF_HOME=/custom/cache $0 unsloth/Qwen3-Coder-Next-GGUF:Q4_K_M"
	exit 1
}

parse_model_ref() {
	local model_ref="$1"

	local repo="${model_ref%%:*}"
	local quant="${model_ref##*:}"

	if [ "$quant" = "$repo" ]; then
		quant="Q4_K_M"
	fi

	echo "$repo|$quant"
}

find_cached_model() {
	local repo="$1"
	local quant="$2"
	local cache_dir="$3"

	local model_pattern="${cache_dir}/${repo//\//_}_${quant}.gguf"
	if [ -f "$model_pattern" ]; then
		echo "$model_pattern"
		return 0
	fi

	model_pattern="${cache_dir}/${repo//\//_}.gguf"
	if [ -f "$model_pattern" ]; then
		echo "$model_pattern"
		return 0
	fi

	echo ""
}

check_llama_cli() {
	if command -v llama-cli &>/dev/null; then
		echo "llama-cli"
		return
	fi

	local local_binary
	local_binary=$(find "$SCRIPT_DIR" -name "llama-cli" -type f 2>/dev/null | head -1)
	if [ -n "$local_binary" ]; then
		echo "$local_binary"
		return
	fi

	echo ""
}

download_model() {
	local model_ref="$1"
	local llama_bin="$2"

	echo "Downloading model..."
	echo "This may take several minutes depending on model size and network speed."
	echo ""

	"$llama_bin" -hf "$model_ref" --log-disable -c 0 2>&1
}

MODEL_REF=""
CUSTOM_CACHE_DIR=""

while [[ $# -gt 0 ]]; do
	case $1 in
	--cache-dir)
		CUSTOM_CACHE_DIR="$2"
		shift 2
		;;
	-h | --help)
		usage
		;;
	*)
		MODEL_REF="$1"
		shift
		;;
	esac
done

if [ -z "$MODEL_REF" ]; then
	usage
fi

if [ -n "$CUSTOM_CACHE_DIR" ]; then
	CACHE_DIR="$CUSTOM_CACHE_DIR"
fi

LLAMA_BIN=$(check_llama_cli)
if [ -z "$LLAMA_BIN" ]; then
	echo "Error: llama-cli not found"
	echo "Please install llama.cpp or place llama-cli in scripts/"
	exit 1
fi

IFS='|' read -r REPO QUANT < <(parse_model_ref "$MODEL_REF")

echo "=== Download Model ==="
echo "Repo:  $REPO"
echo "Quant: $QUANT"
echo "Cache: $CACHE_DIR"
echo ""

EXISTING=$(find_cached_model "$REPO" "$QUANT" "$CACHE_DIR")
if [ -n "$EXISTING" ]; then
	echo "Model already cached!"
	echo "Path: $EXISTING"
	exit 0
fi

echo "Model not found in cache, downloading..."
download_model "$MODEL_REF" "$LLAMA_BIN"

echo ""
echo "=== Download Complete ==="

FINAL_MODEL=$(find_cached_model "$REPO" "$QUANT" "$CACHE_DIR")
if [ -n "$FINAL_MODEL" ]; then
	echo "Cached at: $FINAL_MODEL"
else
	echo "Model should be available in: $CACHE_DIR"
fi

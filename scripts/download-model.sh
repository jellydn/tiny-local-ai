#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${HF_HOME:-$HOME/Library/Caches/llama.cpp}"

detect_gpu_memory() {
	local mem_mb=0

	if command -v llama-cli &>/dev/null; then
		local output
		output=$(llama-cli --log-disable -c 0 2>&1 || true)
		mem_mb=$(echo "$output" | grep 'recommendedMaxWorkingSetSize' | sed 's/.* //' | sed 's/\..*//' | head -1 || echo "0")
		if [ -n "$mem_mb" ] && [ "$mem_mb" -gt 0 ] 2>/dev/null; then
			echo "$mem_mb"
			return
		fi
	fi

	local sys_mem
	sys_mem=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
	sys_mem=$((sys_mem / 1024 / 1024))
	echo "$sys_mem"
}

suggest_quant() {
	local mem_mb="$1"

	echo ""
	echo "=== Recommended Quantization for Your Hardware ==="
	echo "GPU Memory: ~${mem_mb} MB (~$(echo "scale=1; $mem_mb/1024" | bc) GB)"

	local usable_mb=$((mem_mb * 80 / 100))
	echo "Usable (80%): ~${usable_mb} MB (~$(echo "scale=1; $usable_mb/1024" | bc) GB)"
	echo ""

	if [ "$mem_mb" -ge 32000 ]; then
		echo "=== Recommended: M1/M2/M3 Max 32GB ==="
		echo ""
		echo "Best Balance (Coding):"
		echo "  Model: 14B-32B class (e.g., Qwen2.5-Coder-32B, DeepSeek-Coder-V2)"
		echo "  Quant: Q4_K_M"
		echo "  Context: 8K-16K"
		echo "  Speed: 8-15 tok/sec"
		echo ""
		echo "Larger Context (16K+):"
		echo "  Model: 14B class"
		echo "  Quant: Q4_K_M or Q5_K_M"
		echo "  Context: 16K-32K"
		echo ""
		echo "Example: $0 <repo>:Q4_K_M"
		echo ""
		echo "Avoid: 70B+ models (won't fit in GPU working set)"
	elif [ "$mem_mb" -ge 24000 ]; then
		echo "=== Recommended: M3/M2 Pro, M2 Max 24GB ==="
		echo ""
		echo "Best Balance:"
		echo "  Model: 14B class"
		echo "  Quant: Q4_K_M"
		echo "  Context: 8K-16K"
		echo ""
		echo "Larger Context:"
		echo "  Quant: Q4_K_S"
		echo "  Context: 16K-32K"
		echo ""
		echo "Example: $0 <repo>:Q4_K_M"
	elif [ "$mem_mb" -ge 16000 ]; then
		echo "=== Recommended: M2/M1 Pro, M1 Max 16GB ==="
		echo ""
		echo "Best Balance:"
		echo "  Model: 7B-14B class"
		echo "  Quant: Q4_K_M"
		echo "  Context: 8K"
		echo ""
		echo "More Context:"
		echo "  Quant: Q4_K_S"
		echo "  Context: 16K"
		echo ""
		echo "Example: $0 <repo>:Q4_K_M"
	elif [ "$mem_mb" -ge 10000 ]; then
		echo "=== Recommended: M3/M2/M1 (unified memory) ==="
		echo ""
		echo "Best Balance:"
		echo "  Model: 7B class"
		echo "  Quant: Q4_K_S or Q4_K_M"
		echo "  Context: 8K"
		echo ""
		echo "Example: $0 <repo>:Q4_K_S"
	else
		echo "=== Low Memory System ==="
		echo ""
		echo "Recommended:"
		echo "  Model: 7B or smaller"
		echo "  Quant: Q3_K_M or Q2_K"
		echo "  Context: 4K-8K"
		echo ""
		echo "Example: $0 <repo>:Q3_K_S"
	fi

	echo ""
	echo "Context vs Memory Rule:"
	echo "  7B  model -> 32K+ context OK"
	echo "  14B model -> 16K context OK"
	echo "  32B model -> 8K context OK"
	echo ""
	echo "Tip: Use --list to see available quantizations for your repo."
}

usage() {
	echo "Usage: $0 [options] [<repo>[:<quant>]]"
	echo ""
	echo "Arguments:"
	echo "  repo              HuggingFace repo (e.g., unsloth/Qwen3-Coder-Next-GGUF)"
	echo "  quant             Quantization suffix (e.g., UD-Q4_K_XL, Q4_K_M)"
	echo ""
	echo "Options:"
	echo "  -l, --list          List available models in the repository"
	echo "  -s, --suggest      Detect GPU memory and recommend quantization"
	echo "  --cache-dir <path>  Custom cache directory (default: ~/Library/Caches/llama.cpp)"
	echo "  -h, --help          Show this help message"
	echo ""
	echo "Examples:"
	echo "  $0 --suggest                    # Check memory and get recommendation"
	echo "  $0 --list unsloth/Qwen3-Coder-Next-GGUF"
	echo "  $0 unsloth/Qwen3-Coder-Next-GGUF:Q4_K_M"
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

	local repo_slug="${repo//\//_}"

	local found
	found=$(ls "$cache_dir" 2>/dev/null | grep "^${repo_slug}_.*${quant}\.gguf$" | head -1)
	if [ -n "$found" ]; then
		echo "$cache_dir/$found"
		return 0
	fi

	found=$(ls "$cache_dir" 2>/dev/null | grep "^${repo_slug}_${quant}\.gguf$" | head -1)
	if [ -n "$found" ]; then
		echo "$cache_dir/$found"
		return 0
	fi

	echo ""
}

download_model() {
	local repo="$1"
	local quant="$2"
	local cache_dir="$3"
	local token="${HF_TOKEN:-}"

	echo "Downloading model..."
	echo "This may take several minutes depending on model size and network speed."
	echo ""

	local repo_slug="${repo//\//_}"
	local model_file="${repo_slug}_${quant}.gguf"
	local output_path="$cache_dir/$model_file"

	mkdir -p "$cache_dir"

	local url="https://huggingface.co/$repo/resolve/main/$quant/${repo_slug}-${quant}.gguf"

	echo "Trying: $url"
	echo ""

	if [ -n "$token" ]; then
		curl -L -H "Authorization: Bearer $token" -o "$output_path" "$url" --progress-bar 2>&1
	else
		curl -L -o "$output_path" "$url" --progress-bar 2>&1
	fi

	if [ $? -ne 0 ] || [ ! -f "$output_path" ] || [ ! -s "$output_path" ]; then
		rm -f "$output_path"
		echo ""
		echo "Trying alternative path (subfolder)..."

		local alt_url="https://huggingface.co/$repo/resolve/main/$quant/${repo_slug}-${quant}-00001-of-00003.gguf"
		echo "Trying: $alt_url"
		echo ""

		if [ -n "$token" ]; then
			curl -L -H "Authorization: Bearer $token" -o "$output_path" "$alt_url" --progress-bar 2>&1
		else
			curl -L -o "$output_path" "$alt_url" --progress-bar 2>&1
		fi
	fi

	if [ -f "$output_path" ] && [ -s "$output_path" ]; then
		echo ""
		echo "Downloaded to: $output_path"
	else
		curl -L -o "$output_path" "$url" --progress-bar 2>&1
	fi

	if [ $? -ne 0 ] || [ ! -f "$output_path" ] || [ ! -s "$output_path" ]; then
		echo ""
		echo "Trying alternative path (root)..."

		local alt_url="https://huggingface.co/$repo/resolve/main/$model_file"
		echo "Trying: $alt_url"
		echo ""

		if [ -n "$token" ]; then
			curl -L -H "Authorization: Bearer $token" -o "$output_path" "$alt_url" --progress-bar 2>&1
		else
			curl -L -o "$output_path" "$alt_url" --progress-bar 2>&1
		fi
	fi

	if [ -f "$output_path" ] && [ -s "$output_path" ]; then
		echo ""
		echo "Downloaded to: $output_path"
	else
		echo ""
		echo "Error: Download failed. The model file may not exist."
		echo "Try listing available models: ./download-model.sh --list $repo"
	fi
}

list_available_models() {
	local repo="$1"
	local token="${HF_TOKEN:-}"

	echo "=== Available Models ==="
	echo "Repo: $repo"
	echo ""

	if [ -n "$token" ]; then
		response=$(curl -s -H "Authorization: Bearer $token" "https://huggingface.co/api/models/$repo/revision/main" 2>/dev/null)
	else
		response=$(curl -s "https://huggingface.co/api/models/$repo/revision/main" 2>/dev/null)
	fi

	if echo "$response" | grep -q '"siblings"'; then
		files=$(echo "$response" | grep -o '"rfilename":"[^"]*\.gguf"' | sed 's/"rfilename":"//;s/"//g' | sort)
		if [ -z "$files" ]; then
			echo "No .gguf files found in repository."
			echo ""
			echo "Trying alternative API..."
			files=$(curl -s "https://huggingface.co/$repo/tree/main" 2>/dev/null | grep -o 'href="/[^"]*\.gguf"' | sed 's/href="\///;s/\.gguf.*/.gguf/' | sort | uniq)
		fi
	elif [ -z "$token" ]; then
		files=$(curl -s "https://huggingface.co/$repo/tree/main" 2>/dev/null | grep -o 'title="[^"]*\.gguf"' | sed 's/title="//;s/"//g' | sort)
	fi

	if [ -n "$files" ]; then
		echo "$files" | sed 's/^/  /'
		echo ""
		echo "Quantization codes: Q2_K, Q4_0, Q4_K_M, Q5_K_M, Q6_K, Q8_0, UD-Q4_K_XL, etc."
		echo ""
		echo "Usage: $0 <repo>:<quant>"
		echo "Example: $0 $repo:Q4_K_M"
		echo "Example: $0 $repo:UD-Q4_K_XL"
		echo ""
		echo "Usage: $0 <repo>:<quant>"
		echo "Example: $0 $repo:UD-Q4_K_XL"
	else
		echo "Could not fetch model list. Make sure the repository exists."
		echo "You may need to set HF_TOKEN for private repos."
	fi
}

MODEL_REF=""
CUSTOM_CACHE_DIR=""
LIST_MODELS=false
SUGGEST=false

while [[ $# -gt 0 ]]; do
	case $1 in
	-l | --list)
		LIST_MODELS=true
		shift
		;;
	-s | --suggest)
		SUGGEST=true
		shift
		;;
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

if [ "$SUGGEST" = true ]; then
	if [ -n "$CUSTOM_CACHE_DIR" ]; then
		CACHE_DIR="$CUSTOM_CACHE_DIR"
	fi
	MEM_MB=$(detect_gpu_memory)
	suggest_quant "$MEM_MB"
	exit 0
fi

if [ "$LIST_MODELS" = true ]; then
	if [ -z "$MODEL_REF" ]; then
		usage
	fi
	list_available_models "$MODEL_REF"
	exit 0
fi

if [ -z "$MODEL_REF" ]; then
	usage
fi

if [ -n "$CUSTOM_CACHE_DIR" ]; then
	CACHE_DIR="$CUSTOM_CACHE_DIR"
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
download_model "$REPO" "$QUANT" "$CACHE_DIR"

echo ""
echo "=== Download Complete ==="

FINAL_MODEL=$(find_cached_model "$REPO" "$QUANT" "$CACHE_DIR")
if [ -n "$FINAL_MODEL" ]; then
	echo "Cached at: $FINAL_MODEL"
else
	echo "Model should be available in: $CACHE_DIR"
fi

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
	echo "=== Hardware Analysis ==="
	echo "GPU Memory: ~${mem_mb} MB (~$(echo "scale=1; $mem_mb/1024" | bc) GB)"
	echo ""

	local usable_mb=$((mem_mb * 80 / 100))
	echo "Usable (80%): ~${usable_mb} MB (~$(echo "scale=1; $usable_mb/1024" | bc) GB)"
	echo ""

	# Delegate to doctor.py for model recommendations (single source of truth)
	if command -v python3 &>/dev/null; then
		python3 "$SCRIPT_DIR/doctor.py" 2>/dev/null
		echo ""
		echo "For the full list, run: python3 scripts/doctor.py"
	else
		echo "python3 not found. For detailed recommendations, visit:"
		echo "  https://www.canirun.ai/"
		echo "Install python3 to use scripts/doctor.py locally."
	fi
	echo ""
	echo "Data powered by canirun.ai"
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

	# Check for monolithic file
	local found
	found=$(ls "$cache_dir" 2>/dev/null | grep "^${repo_slug}_${quant}\.gguf$" | head -1)
	if [ -n "$found" ]; then
		echo "$cache_dir/$found"
		return 0
	fi

	# Check for sharded directory
	local shard_dir="$cache_dir/${repo_slug}_${quant}"
	if [ -d "$shard_dir" ] && ls "$shard_dir"/*.gguf &>/dev/null 2>&1; then
		echo "$shard_dir"
		return 0
	fi

	echo ""
}

resolve_model_urls() {
	local repo="$1"
	local quant="$2"
	local token="${HF_TOKEN:-}"

	local repo_name="${repo##*/}"
	local model_base="${repo_name%-GGUF}"

	local api_args=()
	if [ -n "$token" ]; then
		api_args=(-H "Authorization: Bearer $token")
	fi

	curl -s "${api_args[@]}" "https://huggingface.co/api/models/$repo/revision/main" 2>/dev/null | \
		python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
ggufs = sorted(s['rfilename'] for s in d.get('siblings', []) if s.get('rfilename', '').endswith('.gguf'))
repo_base = '$model_base'
quant = '$quant'
mono = f'{repo_base}-{quant}.gguf'
# Two sharded-layout conventions exist across HF:
#   1. <quant>/<repo_base>-<quant>-NNNN-of-NNNNN.gguf       (some repos)
#   2. <repo_base>-<quant>.gguf/<repo_base>-<quant>-NNNN.gguf  (bartowski-style)
shards = sorted(
    f for f in ggufs
    if f.startswith(f'{quant}/{repo_base}-{quant}-')
    or f.startswith(f'{repo_base}-{quant}.gguf/{repo_base}-{quant}-')
)
if mono in ggufs:
    print(f'https://huggingface.co/$repo/resolve/main/{mono}')
elif shards:
    for f in shards:
        print(f'https://huggingface.co/$repo/resolve/main/{f}')
else:
    sys.exit(2)
"
}

download_one() {
	local url="$1"
	local out="$2"
	local token="$3"

	echo "  → $out"

	if [ -n "$token" ]; then
		curl -L -H "Authorization: Bearer $token" -o "$out" "$url" --progress-bar 2>&1
	else
		curl -L -o "$out" "$url" --progress-bar 2>&1
	fi

	echo ""		local magic
		magic=$(head -c 4 "$out" 2>/dev/null)
		if [ "$magic" = "GGUF" ]; then
			echo "  ✓ Saved: $out"
			return 0
		else
			local preview
			preview=$(head -c 80 "$out" 2>/dev/null | tr -c '[:print:]	' '?')
			rm -f "$out"
			printf '  \xe2\x9c\x97 Invalid file (not GGUF). First bytes: %s\n' "$preview"
			return 1
		fi
	}

download_model() {
	local repo="$1"
	local quant="$2"
	local cache_dir="$3"
	local token="${HF_TOKEN:-}"

	echo "Resolving file paths from HuggingFace API..."
	echo ""

	local repo_slug="${repo//\//_}"
	mkdir -p "$cache_dir"

	local urls
	local lookup_status
	urls=$(resolve_model_urls "$repo" "$quant" "$token")
	lookup_status=$?
	if [ "$lookup_status" = 1 ]; then
		echo "Error: HuggingFace API lookup failed for $repo (network or auth error)."
		echo "Check your connection and HF_TOKEN settings, then retry."
		exit 1
	fi
	if [ -z "$urls" ]; then
		echo "Error: no files matching $quant found in repo $repo."
		echo "Try listing available models: ./download-model.sh --list $repo"
		exit 1
	fi

	local url_count
	url_count=$(echo "$urls" | wc -l | tr -d ' ')

	if [ "$url_count" -gt 1 ]; then
		# Sharded model — download each shard into a per-quant subdirectory
		local shard_dir="$cache_dir/${repo_slug}_${quant}"
		mkdir -p "$shard_dir"
		echo "Downloading $url_count shards into $shard_dir/"
		echo ""
		local failed=false
		while IFS= read -r url; do
			local fname="${url##*/}"
			local shard_path="$shard_dir/$fname"
			if ! download_one "$url" "$shard_path" "$token"; then
				failed=true
				break
			fi
		done <<<"$urls"
		if [ "$failed" = true ]; then
			# Wipe partial state so find_cached_model won't claim a half-broken set as cached
			rm -rf "$shard_dir"
			exit 1
		fi
	else
		# Monolithic model — single file at standard path
		local url
		url=$(echo "$urls" | head -1)
		local output_path="$cache_dir/${repo_slug}_${quant}.gguf"
		echo "Downloading monolithic file:"
		echo ""
		if ! download_one "$url" "$output_path" "$token"; then
			exit 1
		fi
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

#!/usr/bin/env bash

set -e
set -u

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
format_size() {
	local bytes=$1
	if ((bytes < 1024)); then
		echo "${bytes}B"
	elif ((bytes < 1024 * 1024)); then
		echo "$((bytes / 1024))KB"
	elif ((bytes < 1024 * 1024 * 1024)); then
		echo "$((bytes / 1024 / 1024))MB"
	else
		printf "%.1fGB" "$((bytes * 10 / 1024 / 1024 / 1024))e-1"
	fi
}

get_model_category() {
	local filename=$1
	if [[ $filename == *"Qwen"* ]]; then
		echo "Qwen"
	elif [[ $filename == *"GLM"* ]]; then
		echo "GLM"
	elif [[ $filename == *"MiniMax"* ]]; then
		echo "MiniMax"
	else
		echo "Other"
	fi
}

# Find HuggingFace cache directory
HF_HOME="${HF_HOME:-$HOME/Library/Caches/llama.cpp}"
MODELS_DIR="${MODELS_DIR:-$HOME/models}"

echo -e "${BLUE}=== Model Discovery ===${NC}"
echo ""

# Check local models directory
if [[ -d "$MODELS_DIR" ]]; then
	models_found=0
	echo -e "${YELLOW}📁 Local Models ($MODELS_DIR):${NC}"
	while IFS= read -r file; do
		if [[ -f "$file" ]]; then
			filename=$(basename "$file")
			size=$(stat -f%z "$file" 2>/dev/null || echo 0)
			size_str=$(format_size "$size")
			category=$(get_model_category "$filename")
			echo -e "  ${GREEN}✓${NC} $filename"
			echo "    Category: $category | Size: $size_str"
			models_found=$((models_found + 1))
		fi
	done < <(find "$MODELS_DIR" -maxdepth 1 -name "*.gguf" 2>/dev/null)
	if [[ $models_found -eq 0 ]]; then
		echo -e "  ${RED}✗${NC} No models found"
	fi
else
	echo -e "  ${RED}✗${NC} Directory not found: $MODELS_DIR"
fi

echo ""

# Check HuggingFace cache
if [[ -d "$HF_HOME" ]]; then
	models_found=0
	echo -e "${YELLOW}📁 HuggingFace Cache ($HF_HOME):${NC}"

	# Find all GGUF files in cache
	while IFS= read -r file; do
		if [[ -f "$file" ]]; then
			filename=$(basename "$file")
			size=$(stat -f%z "$file" 2>/dev/null || echo 0)
			size_str=$(format_size "$size")
			category=$(get_model_category "$filename")
			echo -e "  ${GREEN}✓${NC} $filename"
			echo "    Category: $category | Size: $size_str"
			models_found=$((models_found + 1))
		fi
	done < <(find "$HF_HOME" -name "*.gguf" -type f 2>/dev/null | sort)

	if [[ $models_found -eq 0 ]]; then
		echo -e "  ${RED}✗${NC} No models found"
	fi
else
	echo -e "  ${RED}✗${NC} Cache directory not found: $HF_HOME"
fi

echo ""
echo -e "${BLUE}=== Quick Start Commands ===${NC}"
echo ""
echo "List models by category:"
echo "  grep 'Qwen' \$(find $HF_HOME -name '*.gguf' 2>/dev/null | head -1) 2>/dev/null || echo 'Pattern matching'"
echo ""
echo "Start a model:"
echo "  ./scripts/start-llm.sh qwen3-coder-next          # Simple name (case-insensitive)"
echo "  ./scripts/start-llm.sh unsloth/Qwen3-Coder-Next-GGUF  # HuggingFace repo"
echo "  ./scripts/start-llm.sh /path/to/model.gguf        # Full path"
echo ""
echo "Check server status:"
echo "  ./swap status"
echo ""
echo "Swap between models:"
echo "  ./swap qwen"
echo "  ./swap glm"

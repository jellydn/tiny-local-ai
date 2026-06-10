#!/bin/bash
# Fetch latest model and hardware data from canirun.ai
# Usage: ./scripts/fetch-canirun-data.sh [output_dir]
# Default output: ./data/canirun/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${1:-$PROJECT_ROOT/data/canirun}"
CANIRUN_RAW="https://raw.githubusercontent.com/midudev/canirun.ai/main"

mkdir -p "$OUTPUT_DIR"

echo "Fetching canirun.ai data..."

# Model database
curl -sL "$CANIRUN_RAW/src/data/models.ts" -o "$OUTPUT_DIR/models.ts" 2>/dev/null || true

# GGUF sizes
curl -sL "$CANIRUN_RAW/src/data/gguf-sizes.json" -o "$OUTPUT_DIR/gguf-sizes.json" 2>/dev/null || true

# HF stats
curl -sL "$CANIRUN_RAW/src/data/hf-stats.json" -o "$OUTPUT_DIR/hf-stats.json" 2>/dev/null || true

# Try to fetch from packages/models if src/data is a re-export
curl -sL "$CANIRUN_RAW/packages/models/src/index.ts" -o "$OUTPUT_DIR/models-index.ts" 2>/dev/null || true

# Compatibility data
curl -sL "$CANIRUN_RAW/packages/compatibility/src/index.ts" -o "$OUTPUT_DIR/compatibility-index.ts" 2>/dev/null || true

echo "Data saved to $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"

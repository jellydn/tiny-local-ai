#!/bin/bash
# Fetch latest hardware and model data from canirun.ai
# Usage: ./scripts/fetch-canirun-data.sh
# Output: ../data/hardware.json and ../data/models.json
#
# Note: canirun.ai's data is in TypeScript packages. This script fetches
# the raw data files and converts them to JSON for doctor.py to consume.
# If the upstream format changes, this script needs updating.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/data"
CANIRUN_RAW="https://raw.githubusercontent.com/midudev/canirun.ai/main"

mkdir -p "$OUTPUT_DIR"

echo "Fetching canirun.ai data..."

# Fetch raw files
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

fetch_file() {
    local url="$1" outfile="$2"
    if ! curl -sL --fail "$url" -o "$outfile" 2>/dev/null; then
        echo "  [WARN] Failed to fetch: $url" >&2
        return 1
    fi
    if [ ! -s "$outfile" ]; then
        echo "  [WARN] Empty file from: $url" >&2
        return 1
    fi
    return 0
}

# Try to fetch hardware data from packages/compatibility
fetch_file "$CANIRUN_RAW/packages/compatibility/src/index.ts" "$TMP_DIR/compatibility.ts" || true
fetch_file "$CANIRUN_RAW/packages/models/src/index.ts" "$TMP_DIR/models.ts" || true
fetch_file "$CANIRUN_RAW/src/data/gguf-sizes.json" "$TMP_DIR/gguf-sizes.json" || true

# Check if we got usable data
if [ ! -s "$TMP_DIR/compatibility.ts" ] && [ ! -s "$TMP_DIR/models.ts" ]; then
    echo "  [ERROR] Could not fetch canirun.ai data. Using bundled JSON files." >&2
    echo "  Run doctor.py with the bundled data — it will still work." >&2
    exit 1
fi

# Validate downloaded files and report status
echo ""
echo "Downloaded files:"
failed=0
for file in compatibility.ts models.ts gguf-sizes.json; do
    if [ -f "$TMP_DIR/$file" ] && [ -s "$TMP_DIR/$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (missing or empty)"
        failed=$((failed + 1))
    fi
done

# Note: TypeScript-to-JSON conversion is not yet implemented.
# The bundled data/ directory contains the current snapshot.
# To update: edit data/hardware.json and data/models.json directly.
echo ""
echo "Note: TypeScript-to-JSON conversion is not yet implemented."
echo "The bundled data/ directory contains the current snapshot."
echo "To update: edit data/hardware.json and data/models.json directly."

if [ "$failed" -ge 3 ]; then
    echo ""
    echo "  [ERROR] All downloads failed." >&2
    exit 1
fi

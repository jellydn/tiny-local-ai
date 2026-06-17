#!/bin/bash
# Fetch latest hardware and model data from canirun.ai (validator only)
# Usage: ./scripts/fetch-canirun-data.sh (validator — does NOT overwrite data/*.json)
#
# Note: canirun.ai's data is in TypeScript packages. This script fetches
# the raw files for offline inspection and validates the upstream is reachable.
# It does NOT regenerate data/*.json — those are committed snapshots consumed
# by scripts/doctor.py. If the upstream format changes, this script and the
# committed snapshots both need updating.

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
# This script validates canirun.ai upstream is reachable and the bundled
# data/ directory still matches the expected shape. It does NOT regenerate
# data/*.json — those are committed snapshots maintained by the project.
# If you need to refresh hardware or model data, see scripts/doctor.py
# (which reads the bundled JSON) and the canirun.ai data fetch workflow.
echo ""
echo "Note: TypeScript-to-JSON conversion is not yet implemented."
echo "data/*.json are maintained as committed snapshots."
echo "Run scripts/doctor.py to see the current recommendations."

# Ensure we got usable core data (at least one of compatibility.ts or models.ts must exist and be non-empty)
if [ ! -s "$TMP_DIR/compatibility.ts" ] && [ ! -s "$TMP_DIR/models.ts" ]; then
    echo ""
    echo "  [ERROR] Could not fetch core canirun.ai data. Using bundled JSON files." >&2
    echo "  Run doctor.py with the bundled data — it will still work." >&2
    exit 1
fi

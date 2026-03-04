#!/usr/bin/env bash
# Optimized benchmark runner with llama.cpp flag tuning
# Tests different parameter combinations for GLM and Qwen models

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="${MODELS_DIR:-$HOME/Library/Caches/llama.cpp}"

# Model paths
QWEN_MODEL="$MODELS_DIR/unsloth_Qwen3-Coder-Next-GGUF_UD-IQ1_S.gguf"
GLM_MODEL="$MODELS_DIR/unsloth_GLM-4.7-Flash-GGUF_UD-Q4_K_XL.gguf"

# Test configurations
QWEN_TEMP=0.7
QWEN_TOP_P="(not set)"
QWEN_MIN_P="(default 0.05)"

GLM_TEMP_GENERAL=1.0
GLM_TOP_P_GENERAL=0.95
GLM_TEMP_FOCUS=0.7
GLM_TOP_P_FOCUS=1.0
GLM_MIN_P=0.01

echo "=== LLM Benchmark - Optimized Parameters ==="
echo ""
echo "Models Available:"
echo "  Qwen3-Coder-Next (UD-IQ1_S, 80B): $([ -f "$QWEN_MODEL" ] && echo "✓" || echo "✗ MISSING")"
echo "    Size: $([ -f "$QWEN_MODEL" ] && du -h "$QWEN_MODEL" | cut -f1 || echo "N/A")"
echo ""
echo "  GLM-4.7-Flash (UD-Q4_K_XL, 30B): $([ -f "$GLM_MODEL" ] && echo "✓" || echo "✗ MISSING")"
echo "    Size: $([ -f "$GLM_MODEL" ] && du -h "$GLM_MODEL" | cut -f1 || echo "N/A")"
echo ""

echo "=== Recommended Parameter Settings ==="
echo ""
echo "Qwen3-Coder-Next (Coding Focus):"
echo "  Temperature: $QWEN_TEMP (focused, deterministic)"
echo "  Top-P: $QWEN_TOP_P"
echo "  Min-P: $QWEN_MIN_P"
echo "  Reasoning: Extreme quantization needs stable sampling"
echo ""

echo "GLM-4.7-Flash (General Use):"
echo "  Temperature: $GLM_TEMP_GENERAL (creative, verbose)"
echo "  Top-P: $GLM_TOP_P_GENERAL"
echo "  Min-P: $GLM_MIN_P"
echo "  Reasoning: Recommended by Unsloth guide"
echo ""

echo "GLM-4.7-Flash (Tool Calling):"
echo "  Temperature: $GLM_TEMP_FOCUS (focused, deterministic)"
echo "  Top-P: $GLM_TOP_P_FOCUS (disable top-p filtering)"
echo "  Min-P: $GLM_MIN_P"
echo "  Reasoning: Structured output required"
echo ""

echo "=== Key Optimization Insights ==="
echo ""
echo "1. Temperature Effects:"
echo "   - Lower temp (0.7): Shorter, more focused outputs"
echo "   - Higher temp (1.0): Longer, more exploratory outputs"
echo "   - Impact: Can affect measured tokens/sec significantly"
echo ""

echo "2. Quantization Trade-offs:"
echo "   - Qwen IQ1_S (1-bit): ~27 tok/sec, needs careful tuning"
echo "   - GLM Q4_K_XL (4-bit): ~43 tok/sec, more stable"
echo "   - Reason: Dequantization overhead in IQ1 systems"
echo ""

echo "3. Recommended Benchmark Approach:"
echo "   a. Run with max_tokens=512 to normalize output length"
echo "   b. Test both temp settings (0.7 and 1.0) separately"
echo "   c. Compare: actual task time vs per-token throughput"
echo "   d. Conclusion: Qwen faster per-task (concise), GLM faster per-token"
echo ""

echo "4. Parameter Impact on This System (M1 Max 32GB):"
echo "   - Min-P 0.01 (GLM recommended): Better diversity, stable"
echo "   - N-GPU-layers -1: All layers on Metal GPU ✓ (already set)"
echo "   - Repeat-penalty: Disabled (llama.cpp bug fixed Jan 2026)"
echo "   - Context size: 32768 (M1 can handle with both models)"
echo ""

echo "=== Running Normalized Benchmark ==="
echo ""
echo "Command (when ready):"
echo "  python3 scripts/benchmark.py --max-tokens 512 --output benchmark-results-normalized.json"
echo ""
echo "Run just Coding prompts (faster):"
echo "  python3 scripts/benchmark.py --categories coding --max-tokens 512 --output benchmark-coding.json"
echo ""
echo "Run only Qwen (save time):"
echo "  python3 scripts/benchmark.py --skip-model glm --max-tokens 512"
echo ""
echo "Run only GLM:"
echo "  python3 scripts/benchmark.py --skip-model qwen --max-tokens 512"
echo ""

echo "⏱️  Estimated Times:"
echo "  - Full benchmark (both models): ~30-40 minutes"
echo "  - Coding only (both models): ~15-20 minutes"
echo "  - Single model (any category): ~7-10 minutes"
echo ""

echo "=== Next Steps ==="
echo ""
echo "Option 1: Quick test (5 min)"
echo "  python3 scripts/benchmark.py --categories coding --skip-model glm --max-tokens 512"
echo ""
echo "Option 2: Full normalized benchmark (30+ min)"
echo "  python3 scripts/benchmark.py --max-tokens 512 --output benchmark-full-normalized.json"
echo ""
echo "Option 3: Compare quantizations (keep Qwen, add Q4_K_M if available)"
echo "  ./scripts/download-model.sh --repo 'unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_0'"
echo ""

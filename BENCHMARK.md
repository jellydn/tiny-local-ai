# Model Benchmark Tool

Compare the performance of Qwen3-Coder-Next vs GLM-4.7-Flash models on your local system.

## Overview

This benchmark tool automatically:
1. Starts llama-server with each model
2. Runs a series of diverse test prompts (coding, Q&A, reasoning)
3. Measures latency metrics (response time, tokens/sec)
4. Generates detailed comparison reports
5. Saves results as JSON for further analysis

## Features

- **Automatic Server Lifecycle**: Starts and stops llama-server via subprocess
- **Diverse Test Prompts**: 15 prompts across 3 categories
  - **Coding** (5): function writing, debugging, code review, optimization
  - **Q&A** (5): factual questions, explanations, technical concepts
  - **Reasoning** (5): logic puzzles, math problems, pattern recognition
- **Detailed Metrics**: 
  - Total response time (seconds)
  - Tokens per second (throughput)
  - Token count
  - Success/failure status
- **Multiple Output Formats**:
  - Console: ASCII tables with summaries
  - JSON: Complete results with all metrics
- **Category Filtering**: Run only specific test categories

## Requirements

- Python 3.9+
- `openai` package (already installed in your project)
- `llama-server` binary at `/opt/homebrew/bin/llama-server`
- 32GB RAM minimum (sequential runs fit within 32GB)
- Both models cached locally:
  - `~/Library/Caches/llama.cpp/unsloth_Qwen3-Coder-Next-GGUF_UD-IQ1_S.gguf`
  - `~/Library/Caches/llama.cpp/unsloth_GLM-4.7-Flash-GGUF_UD-Q4_K_XL.gguf`

## Usage

### Basic Run (All Prompts)
```bash
python3 scripts/benchmark.py
```

### Run Specific Categories
```bash
# Only coding prompts
python3 scripts/benchmark.py --categories coding

# Coding + Reasoning (skip Q&A)
python3 scripts/benchmark.py --categories coding reasoning
```

### Save Results to Custom File
```bash
python3 scripts/benchmark.py --output my-results.json
```

### Skip a Model
```bash
# Benchmark only Qwen3-Coder-Next (skip GLM-4.7-Flash)
python3 scripts/benchmark.py --skip-model glm

# Benchmark only GLM-4.7-Flash (skip Qwen3)
python3 scripts/benchmark.py --skip-model qwen
```

### Dry Run (Preview without Execution)
```bash
python3 scripts/benchmark.py --dry-run
```

Shows what would run without starting servers or making API calls.

### Custom Timeout (Per-Prompt)
```bash
python3 scripts/benchmark.py --timeout 60
```

Each prompt has 60 seconds to complete before timeout (default: 300 seconds).

### Full Example
```bash
python3 scripts/benchmark.py \
  --categories coding qa \
  --output results-2026-03-04.json \
  --timeout 120
```

## Output

### Console Output Example

```
Loaded 15 test prompts

Qwen3-Coder-Next (UD-IQ1_S, 80B)
======================================================================
  [ 1/15] coding_001 (coding)... ✓ 15.51s (711 tokens)
  [ 2/15] coding_002 (coding)... ✓ 12.34s (645 tokens)
  [ 3/15] coding_003 (coding)... ✓ 18.92s (823 tokens)
  ...

Summary for Qwen3-Coder-Next (UD-IQ1_S, 80B):
  Total Prompts: 15
  Successful: 15
  Failed: 0
  Avg Response Time: 18.50s
  Avg Tokens/sec: 42.30
  Total Tokens: 11234

================================================================================
BENCHMARK COMPARISON
================================================================================
Metric                         Qwen3-Coder-Next          GLM-4.7-Flash            
─────────────────────────────────────────────────────────────────────────────
Total Prompts                  15                        15                       
Successful                     15                        15                       
Failed                         0                         0                        
Avg Response Time (s)          18.50                     12.30                    
Min Response Time (s)          8.20                      5.50                     
Max Response Time (s)          35.60                     28.40                    
Avg Tokens/sec                 42.30                     58.70                    
Min Tokens/sec                 22.10                     35.20                    
Max Tokens/sec                 65.40                     78.50                    
Total Tokens Generated         11234                     8945                     
================================================================================

✓ GLM-4.7-Flash is 33.5% faster (avg response time)
✓ GLM-4.7-Flash is 38.8% faster (tokens/sec)
================================================================================

Results saved to: benchmark-results.json
```

### JSON Output Structure

```json
{
  "timestamp": "2026-03-04 22:29:10",
  "models": [
    {
      "model": "qwen",
      "model_name": "Qwen3-Coder-Next (UD-IQ1_S, 80B)",
      "results": [
        {
          "prompt_id": "coding_001",
          "category": "coding",
          "difficulty": "easy",
          "status": "success",
          "total_time": 15.51,
          "token_count": 711,
          "tokens_per_sec": 45.83,
          "content_length": 677
        },
        ...
      ],
      "summary": {
        "total_prompts": 15,
        "successful": 15,
        "failed": 0,
        "avg_time": 18.50,
        "avg_tokens_per_sec": 42.30,
        "total_tokens": 11234
      }
    },
    {
      "model": "glm",
      "model_name": "GLM-4.7-Flash (UD-Q4_K_XL, 30B)",
      ...
    }
  ],
  "categories": ["all"]
}
```

## Test Prompts

### Coding Tasks
1. **coding_001 (Easy)**: Write Python Fibonacci function with docstring
2. **coding_002 (Easy)**: Write prime number checker
3. **coding_003 (Medium)**: Find and fix a bug in factorial function
4. **coding_004 (Medium)**: Reverse string without slicing + alternatives
5. **coding_005 (Hard)**: Implement binary search with complexity analysis

### Q&A Tasks
1. **qa_001 (Easy)**: What is the capital of France?
2. **qa_002 (Easy)**: Explain photosynthesis in simple terms
3. **qa_003 (Medium)**: SQL vs NoSQL databases with examples
4. **qa_004 (Medium)**: Machine learning vs traditional programming
5. **qa_005 (Hard)**: Blockchain technology and cryptocurrency security

### Reasoning Tasks
1. **reasoning_001 (Easy)**: Height comparison logic puzzle
2. **reasoning_002 (Medium)**: Counting legs problem (chickens & goats)
3. **reasoning_003 (Medium)**: Worker productivity scaling question
4. **reasoning_004 (Hard)**: Optimization problem with budget constraints
5. **reasoning_005 (Hard)**: Set theory - Venn diagram with coffee/tea

## Performance Notes

- **Sequential Execution**: Models run one at a time to fit within 32GB RAM
- **First Run Slower**: Initial model load may take longer as llama.cpp optimizes
- **Warm-up Effect**: Later prompts may be faster as system caches warm up
- **Timeout Handling**: Individual prompt timeouts don't fail entire benchmark
- **GPU Acceleration**: Both models use Metal acceleration (`--n-gpu-layers -1`)

## Files

- `scripts/benchmark.py` - Main benchmark script
- `scripts/benchmark-prompts.json` - Test prompt dataset
- `benchmark-results.json` - Output file (created after benchmark runs)

## Troubleshooting

### "Model not found" Error
Ensure both models are downloaded to the cache directory:
```bash
ls ~/Library/Caches/llama.cpp/*.gguf
```

### Server doesn't start
Check that llama-server is installed:
```bash
which llama-server
# Should output: /opt/homebrew/bin/llama-server
```

### Memory pressure / Crashes
- Run with `--skip-model` to benchmark one model at a time
- Reduce context size (edit `benchmark.py` line for `--ctx-size`)
- Close other applications to free up RAM

### Slow performance
- First run is typically slower due to model loading
- GPU layers must be offloaded (`-1` = all layers)
- Metal acceleration enabled by default on macOS

## Extending the Benchmarks

Add new prompts to `scripts/benchmark-prompts.json`:

```json
{
  "id": "custom_001",
  "category": "coding",
  "difficulty": "medium",
  "prompt": "Your test prompt here",
  "expected_tokens": 100
}
```

Categories must be one of: `coding`, `qa`, `reasoning`

## Further Analysis

The JSON output can be analyzed with Python, Excel, or visualization tools:

```python
import json

with open('benchmark-results.json') as f:
    results = json.load(f)

# Compare average response times
for model in results['models']:
    name = model['model_name']
    avg_time = model['summary']['avg_time']
    print(f"{name}: {avg_time:.2f}s avg response time")
```

---

For more information, see the main [README.md](README.md)

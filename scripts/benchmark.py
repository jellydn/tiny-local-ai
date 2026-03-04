#!/usr/bin/env python3
"""Model benchmark tool to compare Qwen3-Coder-Next vs GLM-4.7-Flash."""

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

from openai import OpenAI


# Configuration
MODELS_CACHE = Path.home() / "Library/Caches/llama.cpp"
LLAMA_SERVER = "/opt/homebrew/bin/llama-server"
BENCHMARK_PROMPTS = Path(__file__).parent / "benchmark-prompts.json"

MODELS = {
    "qwen": {
        "path": MODELS_CACHE / "unsloth_Qwen3-Coder-Next-GGUF_UD-IQ1_S.gguf",
        "port": 8000,
        "display_name": "Qwen3-Coder-Next (UD-IQ1_S, 80B)",
    },
    "glm": {
        "path": MODELS_CACHE / "unsloth_GLM-4.7-Flash-GGUF_UD-Q4_K_XL.gguf",
        "port": 8001,
        "display_name": "GLM-4.7-Flash (UD-Q4_K_XL, 30B)",
    },
}


def load_prompts() -> List[Dict[str, Any]]:
    """Load test prompts from JSON file."""
    if not BENCHMARK_PROMPTS.exists():
        print(f"Error: {BENCHMARK_PROMPTS} not found", file=sys.stderr)
        sys.exit(1)

    with open(BENCHMARK_PROMPTS) as f:
        data = json.load(f)
    return data.get("prompts", [])


def start_server(model_key: str, dry_run: bool = False) -> Optional[subprocess.Popen]:
    """Start llama-server with the specified model."""
    model_info = MODELS[model_key]
    model_path = model_info["path"]
    port = model_info["port"]

    if not model_path.exists():
        print(
            f"Error: Model not found at {model_path}",
            file=sys.stderr,
        )
        sys.exit(1)

    cmd = [
        LLAMA_SERVER,
        "--model",
        str(model_path),
        "--port",
        str(port),
        "--n-gpu-layers",
        "-1",
    ]

    if dry_run:
        print(f"Would run: {' '.join(cmd)}")
        return None

    print(f"Starting {model_info['display_name']} on port {port}...", end=" ")
    sys.stdout.flush()

    try:
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        print("✓")
        return process
    except Exception as e:
        print(f"\nError: {e}", file=sys.stderr)
        sys.exit(1)


def wait_for_server(port: int, timeout: int = 60) -> bool:
    """Wait for server to be ready on the specified port."""
    url = f"http://localhost:{port}/health"
    start = time.time()

    while time.time() - start < timeout:
        try:
            client = OpenAI(base_url=f"http://localhost:{port}/v1", api_key="sk-no-key")
            client.models.list()
            return True
        except Exception:
            time.sleep(2)

    return False


def stop_server(process: Optional[subprocess.Popen]) -> None:
    """Stop the llama-server process."""
    if process is None:
        return

    try:
        process.terminate()
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()


def measure_prompt(
    client: OpenAI, model_name: str, prompt: str, timeout: int = 300
) -> Dict[str, Any]:
    """Run a single prompt and measure latency metrics."""
    start_time = time.time()
    ttft = None
    token_count = 0
    first_token_time = None

    try:
        response = client.chat.completions.create(
            model=model_name,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.7,
            timeout=timeout,
        )

        total_time = time.time() - start_time
        content = response.choices[0].message.content or ""
        token_count = len(content.split())

        if response.usage:
            token_count = response.usage.completion_tokens

        return {
            "status": "success",
            "total_time": total_time,
            "token_count": token_count,
            "ttft": ttft,
            "tokens_per_sec": (token_count / total_time if total_time > 0 else 0),
            "content_length": len(content),
        }
    except Exception as e:
        return {
            "status": "error",
            "error": str(e),
            "total_time": time.time() - start_time,
            "token_count": 0,
            "ttft": None,
            "tokens_per_sec": 0,
        }


def run_benchmark_for_model(
    model_key: str,
    prompts: List[Dict[str, Any]],
    categories: Optional[List[str]] = None,
    dry_run: bool = False,
    timeout: int = 300,
) -> Dict[str, Any]:
    """Run benchmark for a single model."""
    model_info = MODELS[model_key]
    filtered_prompts = prompts

    if categories:
        filtered_prompts = [p for p in prompts if p.get("category") in categories]

    print(f"\n{model_info['display_name']}")
    print("=" * 70)

    server_process = start_server(model_key, dry_run=dry_run)

    if dry_run:
        print(f"Would run {len(filtered_prompts)} prompts")
        return {
            "model": model_key,
            "model_name": model_info["display_name"],
            "results": [],
            "summary": {},
        }

    if not wait_for_server(model_info["port"]):
        print("Error: Server did not start", file=sys.stderr)
        stop_server(server_process)
        sys.exit(1)

    client = OpenAI(
        base_url=f"http://localhost:{model_info['port']}/v1", api_key="sk-no-key"
    )

    results = []
    for i, prompt_data in enumerate(filtered_prompts, 1):
        prompt_id = prompt_data.get("id", f"prompt_{i}")
        category = prompt_data.get("category", "unknown")
        prompt_text = prompt_data.get("prompt", "")

        print(
            f"  [{i:2d}/{len(filtered_prompts)}] {prompt_id} ({category})...",
            end=" ",
            flush=True,
        )

        metrics = measure_prompt(client, model_key, prompt_text, timeout=timeout)
        print(f"✓ {metrics['total_time']:.2f}s ({metrics['token_count']} tokens)")

        results.append(
            {
                "prompt_id": prompt_id,
                "category": category,
                "difficulty": prompt_data.get("difficulty"),
                **metrics,
            }
        )

    stop_server(server_process)
    print(f"\nStopping server... ✓")

    summary = compute_summary(results)

    return {
        "model": model_key,
        "model_name": model_info["display_name"],
        "results": results,
        "summary": summary,
    }


def compute_summary(results: list[dict[str, Any]]) -> Dict[str, Any]:
    """Compute summary statistics for benchmark results."""
    successful = [r for r in results if r.get("status") == "success"]

    if not successful:
        return {
            "total_prompts": len(results),
            "successful": 0,
            "failed": len(results),
            "avg_time": 0,
            "avg_tokens_per_sec": 0,
        }

    times = [r["total_time"] for r in successful]
    tokens_per_sec = [r["tokens_per_sec"] for r in successful]
    token_counts = [r["token_count"] for r in successful]

    return {
        "total_prompts": len(results),
        "successful": len(successful),
        "failed": len(results) - len(successful),
        "avg_time": sum(times) / len(times),
        "min_time": min(times),
        "max_time": max(times),
        "total_tokens": sum(token_counts),
        "avg_tokens_per_sec": sum(tokens_per_sec) / len(tokens_per_sec),
        "min_tokens_per_sec": min(tokens_per_sec),
        "max_tokens_per_sec": max(tokens_per_sec),
    }


def format_results_table(results: list[dict[str, Any]], max_width: int = 120) -> str:
    """Format benchmark results as ASCII table."""
    lines = []
    lines.append("=" * max_width)
    lines.append(
        f"{'Prompt ID':<15} {'Category':<12} {'Status':<10} {'Time(s)':<10} {'Tokens':<10} {'Tokens/s':<10}"
    )
    lines.append("-" * max_width)

    for result in results:
        prompt_id = result.get("prompt_id", "?")[:14]
        category = result.get("category", "?")[:11]
        status = result.get("status", "?")[:9]
        total_time = result.get("total_time", 0)
        token_count = result.get("token_count", 0)
        tokens_per_sec = result.get("tokens_per_sec", 0)

        lines.append(
            f"{prompt_id:<15} {category:<12} {status:<10} {total_time:>9.2f} {token_count:>9d} {tokens_per_sec:>9.2f}"
        )

    lines.append("=" * max_width)
    return "\n".join(lines)


def format_comparison(qwen_data: dict[str, Any], glm_data: dict[str, Any]) -> str:
    """Format comparison between two models."""
    lines = []
    lines.append("\n" + "=" * 80)
    lines.append("BENCHMARK COMPARISON")
    lines.append("=" * 80)

    qwen_summary = qwen_data.get("summary", {})
    glm_summary = glm_data.get("summary", {})

    qwen_avg_time = qwen_summary.get("avg_time", 0)
    glm_avg_time = glm_summary.get("avg_time", 0)

    qwen_avg_tps = qwen_summary.get("avg_tokens_per_sec", 0)
    glm_avg_tps = glm_summary.get("avg_tokens_per_sec", 0)

    qwen_total = qwen_summary.get("total_prompts", 0)
    glm_total = glm_summary.get("total_prompts", 0)

    lines.append(f"{'Metric':<30} {'Qwen3-Coder-Next':<25} {'GLM-4.7-Flash':<25}")
    lines.append("-" * 80)

    lines.append(f"{'Total Prompts':<30} {qwen_total:<25d} {glm_total:<25d}")
    lines.append(
        f"{'Successful':<30} {qwen_summary.get('successful', 0):<25d} {glm_summary.get('successful', 0):<25d}"
    )
    lines.append(
        f"{'Failed':<30} {qwen_summary.get('failed', 0):<25d} {glm_summary.get('failed', 0):<25d}"
    )

    lines.append(
        f"{'Avg Response Time (s)':<30} {qwen_avg_time:<25.2f} {glm_avg_time:<25.2f}"
    )
    lines.append(
        f"{'Min Response Time (s)':<30} {qwen_summary.get('min_time', 0):<25.2f} {glm_summary.get('min_time', 0):<25.2f}"
    )
    lines.append(
        f"{'Max Response Time (s)':<30} {qwen_summary.get('max_time', 0):<25.2f} {glm_summary.get('max_time', 0):<25.2f}"
    )

    lines.append(f"{'Avg Tokens/sec':<30} {qwen_avg_tps:<25.2f} {glm_avg_tps:<25.2f}")
    lines.append(
        f"{'Min Tokens/sec':<30} {qwen_summary.get('min_tokens_per_sec', 0):<25.2f} {glm_summary.get('min_tokens_per_sec', 0):<25.2f}"
    )
    lines.append(
        f"{'Max Tokens/sec':<30} {qwen_summary.get('max_tokens_per_sec', 0):<25.2f} {glm_summary.get('max_tokens_per_sec', 0):<25.2f}"
    )

    lines.append(
        f"{'Total Tokens Generated':<30} {qwen_summary.get('total_tokens', 0):<25d} {glm_summary.get('total_tokens', 0):<25d}"
    )

    lines.append("=" * 80)

    if qwen_avg_time > 0 and glm_avg_time > 0:
        time_diff_pct = ((qwen_avg_time - glm_avg_time) / glm_avg_time) * 100
        if time_diff_pct < 0:
            lines.append(
                f"\n✓ GLM-4.7-Flash is {abs(time_diff_pct):.1f}% faster (avg response time)"
            )
        else:
            lines.append(
                f"\n✓ Qwen3-Coder-Next is {time_diff_pct:.1f}% faster (avg response time)"
            )

    if glm_avg_tps > 0 and qwen_avg_tps > 0:
        tps_diff_pct = ((glm_avg_tps - qwen_avg_tps) / qwen_avg_tps) * 100
        if tps_diff_pct > 0:
            lines.append(f"✓ GLM-4.7-Flash is {tps_diff_pct:.1f}% faster (tokens/sec)")
        else:
            lines.append(
                f"✓ Qwen3-Coder-Next is {abs(tps_diff_pct):.1f}% faster (tokens/sec)"
            )

    lines.append("=" * 80)

    return "\n".join(lines)


def main():
    """Main benchmark function."""
    parser = argparse.ArgumentParser(
        description="Benchmark Qwen3-Coder-Next vs GLM-4.7-Flash"
    )
    parser.add_argument(
        "--output",
        default="benchmark-results.json",
        help="Output file for JSON results (default: benchmark-results.json)",
    )
    parser.add_argument(
        "--categories",
        nargs="+",
        choices=["coding", "qa", "reasoning"],
        help="Filter prompts by category (default: all)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would run without executing",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=300,
        help="Per-prompt timeout in seconds (default: 300)",
    )
    parser.add_argument(
        "--skip-model",
        choices=["qwen", "glm"],
        help="Skip benchmarking a specific model",
    )

    args = parser.parse_args()

    prompts = load_prompts()
    print(f"Loaded {len(prompts)} test prompts")

    all_results = []

    models_to_run = ["qwen", "glm"]
    if args.skip_model:
        models_to_run.remove(args.skip_model)

    for model_key in models_to_run:
        model_results = run_benchmark_for_model(
            model_key,
            prompts,
            categories=args.categories,
            dry_run=args.dry_run,
            timeout=args.timeout,
        )

        print("\n" + format_results_table(model_results["results"]))
        print(f"\nSummary for {model_results['model_name']}:")
        summary = model_results["summary"]
        print(f"  Total Prompts: {summary.get('total_prompts', 0)}")
        print(f"  Successful: {summary.get('successful', 0)}")
        print(f"  Failed: {summary.get('failed', 0)}")
        print(f"  Avg Response Time: {summary.get('avg_time', 0):.2f}s")
        print(f"  Avg Tokens/sec: {summary.get('avg_tokens_per_sec', 0):.2f}")
        print(f"  Total Tokens: {summary.get('total_tokens', 0)}")

        all_results.append(model_results)

    if len(all_results) == 2:
        print(format_comparison(all_results[0], all_results[1]))

    if not args.dry_run:
        output_path = Path(args.output)
        with open(output_path, "w") as f:
            json.dump(
                {
                    "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
                    "models": all_results,
                    "categories": args.categories or ["all"],
                },
                f,
                indent=2,
            )
        print(f"\nResults saved to: {output_path}")


if __name__ == "__main__":
    main()

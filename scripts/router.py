#!/usr/bin/env python3
"""Smart router for Tiny Local AI - Routes prompts to optimal model."""

import argparse
import json
import re
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

from openai import OpenAI


CODING_KEYWORDS = [
    "code",
    "function",
    "class",
    "implement",
    "write",
    "debug",
    "fix",
    "refactor",
    "test",
    "api",
    "python",
    "javascript",
    "typescript",
    "rust",
    "go",
    "java",
    "c++",
    "sql",
    "query",
    "algorithm",
    "bug",
    "error",
    "exception",
    "import",
    "export",
    "module",
    "interface",
    "type",
    "enum",
    "struct",
    "trait",
    "async",
    "await",
    "promise",
    "callback",
    "hook",
    "component",
    "render",
    "props",
    "state",
    " redux",
    "router",
    "http",
    "endpoint",
    "rest",
    "graphql",
    "database",
    "schema",
    "migration",
]

CODING_PATTERNS = [
    r"def\s+\w+\s*\(",
    r"class\s+\w+",
    r"function\s+\w+\s*\(",
    r"const\s+\w+\s*=",
    r"let\s+\w+\s*=",
    r"var\s+\w+\s*=",
    r"import\s+.*from",
    r"export\s+(default\s+)?",
    r"<!DOCTYPE\s+html",
    r"<html",
    r"```\w+",
    r"#include",
    r"package\s+\w+",
]


class Router:
    """Smart prompt router for local LLM models."""

    MODEL_PORTS = {
        "qwen": "http://localhost:8000/v1",
        "glm": "http://localhost:8001/v1",
    }

    def __init__(
        self,
        base_url: str = "http://localhost:8000/v1",
        api_key: str = "sk-no-key",
    ):
        self.base_url = base_url
        self.api_key = api_key
        self.stats = {
            "total_requests": 0,
            "coding_routed": 0,
            "general_routed": 0,
            "qwen_used": 0,
            "glm_used": 0,
            "total_tokens": 0,
            "total_time": 0,
        }

    def detect_task_type(self, prompt: str) -> str:
        """Detect if prompt is coding-related or general."""
        prompt_clean = " " + prompt.lower() + " "

        coding_score = 0
        for keyword in CODING_KEYWORDS:
            if keyword in prompt_clean:
                coding_score += 1

        for pattern in CODING_PATTERNS:
            if re.search(pattern, prompt):
                coding_score += 2

        if coding_score >= 2:
            return "coding"
        if coding_score == 1:
            if any(
                w in prompt_clean
                for w in ["python", "javascript", "code", "function", "class", "api"]
            ):
                return "coding"

        return "general"

    def route_model(self, task_type: str, prefer: Optional[str] = None) -> str:
        """Route to optimal model based on task type."""
        if prefer:
            return prefer

        if task_type == "coding":
            return "qwen"
        return "glm"

    def get_model_config(self, model: str) -> Dict[str, Any]:
        """Get model-specific configuration."""
        configs = {
            "qwen": {
                "model": "unsloth_Qwen3-Coder-Next-GGUF_UD-IQ1_S.gguf",
                "temperature": 0.7,
                "max_tokens": 512,
                "stop": [],
            },
            "glm": {
                "model": "unsloth_GLM-4.7-Flash-GGUF_UD-Q4_K_XL.gguf",
                "temperature": 0.7,
                "max_tokens": 512,
                "top_p": 1.0,
                "min_p": 0.01,
            },
        }
        return configs.get(model, configs["glm"])

    def generate(
        self,
        prompt: str,
        task_type: Optional[str] = None,
        prefer: Optional[str] = None,
        stream: bool = False,
        max_tokens: int = 512,
    ) -> Dict[str, Any]:
        """Generate response with smart routing."""
        start_time = time.time()

        detected_type = task_type or self.detect_task_type(prompt)
        model = self.route_model(detected_type, prefer)

        self.stats["total_requests"] += 1
        if detected_type == "coding":
            self.stats["coding_routed"] += 1
        else:
            self.stats["general_routed"] += 1

        if model == "qwen":
            self.stats["qwen_used"] += 1
        else:
            self.stats["glm_used"] += 1

        model_url = self.MODEL_PORTS.get(model, self.base_url)
        client = OpenAI(base_url=model_url, api_key=self.api_key)

        config = self.get_model_config(model)
        config["max_tokens"] = max_tokens

        try:
            response = client.chat.completions.create(
                model=config["model"],
                messages=[{"role": "user", "content": prompt}],
                temperature=config["temperature"],
                max_tokens=config["max_tokens"],
                stream=stream,
            )

            if stream:
                return {
                    "streaming": True,
                    "model": model,
                    "task_type": detected_type,
                    "stream": response,
                }

            elapsed = time.time() - start_time
            content = response.choices[0].message.content
            tokens = response.usage.completion_tokens if response.usage else 0
            tok_per_sec = tokens / elapsed if elapsed > 0 else 0

            self.stats["total_tokens"] += tokens
            self.stats["total_time"] += elapsed

            return {
                "content": content,
                "model": model,
                "task_type": detected_type,
                "tokens": tokens,
                "time": elapsed,
                "tok_per_sec": tok_per_sec,
            }

        except Exception as e:
            return {
                "error": str(e),
                "model": model,
                "task_type": detected_type,
            }

    def print_stats(self) -> None:
        """Print routing statistics."""
        print("\n" + "=" * 50)
        print("  ROUTER STATISTICS")
        print("=" * 50)
        print(f"  Total Requests:     {self.stats['total_requests']}")
        print(f"  Coding Routed:      {self.stats['coding_routed']}")
        print(f"  General Routed:    {self.stats['general_routed']}")
        print(f"  Qwen Used:         {self.stats['qwen_used']}")
        print(f"  GLM Used:          {self.stats['glm_used']}")
        print(f"  Total Tokens:      {self.stats['total_tokens']}")
        print(f"  Total Time:        {self.stats['total_time']:.2f}s")
        if self.stats["total_time"] > 0:
            avg = self.stats["total_tokens"] / self.stats["total_time"]
            print(f"  Avg Tokens/sec:    {avg:.2f}")
        print("=" * 50 + "\n")


def main() -> int:
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(description="Smart router for Tiny Local AI")
    parser.add_argument("prompt", nargs="?", help="Prompt to send")
    parser.add_argument(
        "--model",
        "-m",
        choices=["qwen", "glm", "auto"],
        default="auto",
        help="Model to use (auto routes based on task)",
    )
    parser.add_argument(
        "--type",
        "-t",
        choices=["coding", "general", "auto"],
        default="auto",
        help="Task type hint (auto-detects if not specified)",
    )
    parser.add_argument(
        "--max-tokens", type=int, default=512, help="Max tokens to generate"
    )
    parser.add_argument("--stream", action="store_true", help="Stream response")
    parser.add_argument(
        "--stats", action="store_true", help="Show router statistics after generation"
    )
    parser.add_argument(
        "--url", default="http://localhost:8000/v1", help="Base URL for llama-server"
    )

    args = parser.parse_args()

    if not args.prompt:
        parser.print_help()
        return 1

    router = Router(base_url=args.url)

    task_type = None
    if args.type != "auto":
        task_type = args.type

    prefer = None
    if args.model != "auto":
        prefer = args.model

    result = router.generate(
        prompt=args.prompt,
        task_type=task_type,
        prefer=prefer,
        stream=args.stream,
        max_tokens=args.max_tokens,
    )

    if "error" in result:
        print(f"Error: {result['error']}", file=sys.stderr)
        return 1

    if result.get("streaming"):
        print(f"[Router: {result['model']} | Type: {result['task_type']}]")
        for chunk in result["stream"]:
            if chunk.choices[0].delta.content:
                print(chunk.choices[0].delta.content, end="")
        print()
    else:
        print(f"[Router: {result['model']} | Type: {result['task_type']}]")
        print(
            f"[Tokens: {result['tokens']} | Time: {result['time']:.2f}s | Speed: {result['tok_per_sec']:.1f} tok/s]"
        )
        print()
        print(result["content"])

    if args.stats:
        router.print_stats()

    return 0


if __name__ == "__main__":
    sys.exit(main())

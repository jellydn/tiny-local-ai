#!/usr/bin/env python3
"""Hot-swap model on running llama-server without downtime."""

import argparse
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional, Tuple

MODELS_CACHE = Path.home() / "Library/Caches/llama.cpp"
LLAMA_SERVER = "/opt/homebrew/bin/llama-server"

MODEL_CONFIGS = {
    "qwen": {
        "path": MODELS_CACHE / "unsloth_Qwen3-Coder-Next-GGUF_UD-IQ1_S.gguf",
        "port": 8000,
        "ctx_size": 32768,
        "temp": 0.7,
        "repeat_penalty": 1.0,
        "name": "Qwen3-Coder-Next (IQ1_S)",
    },
    "glm": {
        "path": MODELS_CACHE / "unsloth_GLM-4.7-Flash-GGUF_UD-Q4_K_XL.gguf",
        "port": 8000,
        "ctx_size": 32768,
        "temp": 0.7,
        "top_p": 1.0,
        "min_p": 0.01,
        "name": "GLM-4.7-Flash (Q4_K_XL)",
    },
}


def get_current_model() -> Optional[str]:
    """Check which model is currently running."""
    try:
        result = subprocess.run(
            ["curl", "-s", "http://localhost:8000/v1/models"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode != 0:
            return None

        import json

        data = json.loads(result.stdout)
        model_id = data.get("data", [{}])[0].get("id", "")

        for key, config in MODEL_CONFIGS.items():
            if config["path"].name in model_id:
                return key

        return model_id if model_id else None
    except Exception:
        return None


def wait_for_server(timeout: int = 60) -> bool:
    """Wait for server to become ready."""
    start = time.time()
    while time.time() - start < timeout:
        try:
            result = subprocess.run(
                ["curl", "-s", "http://localhost:8000/v1/models"],
                capture_output=True,
                timeout=2,
            )
            if result.returncode == 0:
                return True
        except Exception:
            pass
        time.sleep(2)
    return False


def stop_server() -> bool:
    """Stop the running llama-server."""
    try:
        subprocess.run(
            ["pkill", "-f", "llama-server"],
            capture_output=True,
        )
        time.sleep(2)
        return True
    except Exception:
        return False


def start_server(model_key: str) -> bool:
    """Start llama-server with specified model."""
    config = MODEL_CONFIGS.get(model_key)
    if not config:
        print(f"Error: Unknown model '{model_key}'")
        return False

    model_path = config["path"]
    if not model_path.exists():
        print(f"Error: Model not found at {model_path}")
        return False

    cmd = [
        LLAMA_SERVER,
        "-m",
        str(model_path),
        "--host",
        "127.0.0.1",
        "--port",
        str(config["port"]),
        "--ctx-size",
        str(config["ctx_size"]),
        "--n-gpu-layers",
        "-1",
        "--temp",
        str(config["temp"]),
    ]

    if "repeat_penalty" in config:
        cmd.extend(["--repeat-penalty", str(config["repeat_penalty"])])
    if "top_p" in config:
        cmd.extend(["--top-p", str(config["top_p"])])
    if "min_p" in config:
        cmd.extend(["--min-p", str(config["min_p"])])

    print(f"Starting {config['name']}...")
    print(f"Command: {' '.join(cmd)}")

    try:
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return wait_for_server()
    except Exception as e:
        print(f"Error starting server: {e}")
        return False


def swap_model(target_model: str) -> Tuple[bool, str]:
    """Swap to a different model with minimal downtime."""
    current = get_current_model()

    if current == target_model:
        config = MODEL_CONFIGS[target_model]
        return True, f"✓ Already running {config['name']}"

    print(f"Current model: {current or 'None'}")
    print(f"Target model: {target_model}")

    if current:
        print("Stopping current server...")
        stop_server()

    print(f"Starting new model...")
    if start_server(target_model):
        config = MODEL_CONFIGS[target_model]
        return True, f"✓ Swapped to {config['name']}"

    return False, "✗ Failed to start new model"


def status() -> None:
    """Show current server status."""
    current = get_current_model()

    print("\n" + "=" * 50)
    print("  Tiny Local AI - Server Status")
    print("=" * 50)

    if current:
        config = MODEL_CONFIGS[current]
        print(f"  Model:     {config['name']}")
        print(f"  Status:    ✅ Running")
        print(f"  URL:       http://localhost:8000/v1")
    else:
        print("  Status:    ❌ No server running")

    print("\n  Available models:")
    for key, config in MODEL_CONFIGS.items():
        marker = "→" if key == current else " "
        print(f"    {marker} {key}: {config['name']}")

    print("=" * 50 + "\n")


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Hot-swap models on llama-server")
    parser.add_argument(
        "action",
        choices=["status", "swap", "qwen", "glm"],
        help="Action to perform",
    )
    parser.add_argument(
        "--wait",
        "-w",
        type=int,
        default=60,
        help="Max seconds to wait for server (default: 60)",
    )

    args = parser.parse_args()

    if args.action == "status":
        status()
        return 0

    target = args.action if args.action in ["qwen", "glm"] else None

    if target:
        success, message = swap_model(target)
        print(message)
        return 0 if success else 1

    return 0


if __name__ == "__main__":
    sys.exit(main())

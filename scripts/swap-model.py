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


import json


def is_server_healthy() -> Tuple[bool, Optional[str]]:
    """Check if server is healthy and responding correctly.

    Returns:
        Tuple of (is_healthy, model_id or None)
    """
    try:
        result = subprocess.run(
            ["curl", "-s", "http://localhost:8000/v1/models"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode != 0:
            return False, None

        data = json.loads(result.stdout)
        model_data = data.get("data", [])

        if not model_data or not isinstance(model_data, list):
            return False, None

        model_id = model_data[0].get("id", "")
        return bool(model_id), model_id
    except Exception:
        return False, None


def get_current_model(verbose: bool = False) -> Optional[str]:
    """Check which model is currently running with retries."""
    max_retries = 3
    retry_delay = 1

    for attempt in range(max_retries):
        try:
            is_healthy, model_id = is_server_healthy()
            if not is_healthy:
                if verbose and attempt < max_retries - 1:
                    print(f"  [Retry {attempt + 1}/{max_retries}] Server not responding yet...")
                if attempt < max_retries - 1:
                    time.sleep(retry_delay)
                continue

            if not model_id:
                return None

            for key, config in MODEL_CONFIGS.items():
                if config["path"].name in model_id:
                    return key

            return model_id
        except Exception as e:
            if verbose:
                print(f"  [Error in get_current_model]: {e}", file=sys.stderr)
            if attempt < max_retries - 1:
                time.sleep(retry_delay)

    return None


def wait_for_server(
    timeout: int = 90, verbose: bool = False, progress_interval: int = 5
) -> bool:
    """Wait for server to become ready with improved validation.

    Args:
        timeout: Maximum seconds to wait (default 90s for model loading)
        verbose: Print progress messages
        progress_interval: Print progress every N seconds

    Returns:
        True if server became healthy, False if timeout
    """
    start = time.time()
    last_progress = start

    while time.time() - start < timeout:
        elapsed = time.time() - start

        # Print progress periodically
        if verbose and elapsed - (last_progress - start) >= progress_interval:
            print(f"  Still waiting for server... ({int(elapsed)}s elapsed)", flush=True)
            last_progress = time.time()

        try:
            is_healthy, model_id = is_server_healthy()
            if is_healthy:
                return True
        except Exception:
            pass

        time.sleep(2)

    return False


def check_process_running() -> Optional[Tuple[str, str]]:
    """Check if llama-server process is running.

    Returns:
        Tuple of (process_info, model_name) if running, None otherwise
    """
    try:
        result = subprocess.run(
            ["pgrep", "-a", "llama-server"],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0 or not result.stdout.strip():
            return None

        output = result.stdout.strip()

        # Try to identify which model from the process command line
        for key, config in MODEL_CONFIGS.items():
            if config["path"].name in output:
                return output, key

        # Unknown model but process is running
        return output, None
    except Exception:
        return None


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


def start_server(model_key: str, wait_timeout: int = 90) -> bool:
    """Start llama-server with specified model.
    
    Args:
        model_key: Model identifier (qwen or glm)
        wait_timeout: Maximum seconds to wait for server startup
    
    Returns:
        True if server started and became healthy, False otherwise
    """
    config = MODEL_CONFIGS.get(model_key)
    if not config:
        print(f"Error: Unknown model '{model_key}'")
        return False

    model_path = config["path"]
    if not model_path.exists():
        print(f"Error: Model not found at {model_path}")
        print(f"  Expected location: {model_path}")
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

    try:
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if wait_for_server(timeout=wait_timeout, verbose=True):
            return True

        # Server didn't respond, check if process is still alive
        proc_info = check_process_running()
        if proc_info:
            print(f"✗ Server process started but failed to become ready (timeout after {wait_timeout}s)")
            print(f"  Try checking system resources or increasing timeout with: ./swap {model_key} --wait 120")
        else:
            print(f"✗ Server process exited unexpectedly")
            print(f"  Try running: llama-server -m {model_path}")
        return False
    except Exception as e:
        print(f"✗ Error starting server: {e}")
        return False


def swap_model(target_model: str, wait_timeout: int = 90) -> Tuple[bool, str]:
    """Swap to a different model with minimal downtime.
    
    Args:
        target_model: Target model identifier (qwen or glm)
        wait_timeout: Maximum seconds to wait for server startup
    
    Returns:
        Tuple of (success: bool, message: str)
    """
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
    if start_server(target_model, wait_timeout=wait_timeout):
        config = MODEL_CONFIGS[target_model]
        return True, f"✓ Swapped to {config['name']}"

    return False, "✗ Failed to start new model"


def status() -> None:
    """Show current server status with API and process-level detection."""
    current = get_current_model()
    proc_info = check_process_running() if not current else None

    print("\n" + "=" * 50)
    print("  Tiny Local AI - Server Status")
    print("=" * 50)

    if current:
        config = MODEL_CONFIGS[current]
        print(f"  Model:     {config['name']}")
        print(f"  Status:    ✅ Running")
        print(f"  URL:       http://localhost:8000/v1")
    elif proc_info:
        proc_output, model_key = proc_info
        if model_key:
            config = MODEL_CONFIGS[model_key]
            print(f"  Model:     {config['name']}")
            print(f"  Status:    ⏳ Starting (process running, waiting for API...)")
            print(f"  URL:       http://localhost:8000/v1 (not yet responding)")
        else:
            print(f"  Status:    ⏳ Server starting (model unknown)")
            print(f"  Process:   {proc_output[:80]}...")
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
        default=90,
        help="Max seconds to wait for server startup (default: 90)",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Show detailed progress messages",
    )

    args = parser.parse_args()

    if args.action == "status":
        status()
        return 0

    target = args.action if args.action in ["qwen", "glm"] else None

    if target:
        success, message = swap_model(target, wait_timeout=args.wait)
        print(message)
        return 0 if success else 1

    return 0


if __name__ == "__main__":
    sys.exit(main())

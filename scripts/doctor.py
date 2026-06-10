#!/usr/bin/env python3
"""Hardware detection and model recommendation for Tiny Local AI.

Uses canirun.ai hardware database and model compatibility data.
Fetches latest data from https://github.com/midudev/canirun.ai
"""

import json
import os
import platform
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

MODELS_CACHE = Path.home() / "Library/Caches/llama.cpp"
CANIRUN_DATA_DIR = Path(__file__).parent.parent / "data" / "canirun"

# ---------------------------------------------------------------------------
# Hardware database (from canirun.ai)
# ---------------------------------------------------------------------------

APPLE_SILICON = {
    "M1": {"ram_options": [8, 16], "gpu_cores": {"base": 7, "pro": 8, "max": 24, "ultra": 48}},
    "M1 Pro": {"ram_options": [16, 32], "gpu_cores": 14},
    "M1 Max": {"ram_options": [32, 64], "gpu_cores": 24},
    "M1 Ultra": {"ram_options": [64, 128], "gpu_cores": 48},
    "M2": {"ram_options": [8, 16, 24], "gpu_cores": {"base": 8, "pro": 10, "max": 30, "ultra": 60}},
    "M2 Pro": {"ram_options": [16, 32], "gpu_cores": 16},
    "M2 Max": {"ram_options": [32, 64, 96], "gpu_cores": 30},
    "M2 Ultra": {"ram_options": [64, 128, 192], "gpu_cores": 60},
    "M3": {"ram_options": [8, 16, 24], "gpu_cores": {"base": 8, "pro": 10, "max": 30}},
    "M3 Pro": {"ram_options": [18, 36], "gpu_cores": 14},
    "M3 Max": {"ram_options": [36, 64, 96, 128], "gpu_cores": 30},
    "M3 Ultra": {"ram_options": [96, 192], "gpu_cores": 60},
    "M4": {"ram_options": [16, 24, 32], "gpu_cores": {"base": 8, "pro": 10, "max": 32}},
    "M4 Pro": {"ram_options": [24, 48], "gpu_cores": 16},
    "M4 Max": {"ram_options": [36, 64, 128], "gpu_cores": 32},
    "M5": {"ram_options": [16, 24], "gpu_cores": {"base": 8, "pro": 10, "max": 32}},
    "M5 Pro": {"ram_options": [24, 48], "gpu_cores": 16},
    "M5 Max": {"ram_options": [36, 64], "gpu_cores": 32},
}

NVIDIA_GPUS = {
    "RTX 5090": {"vram": 32, "tier": "enthusiast"},
    "RTX 5080": {"vram": 16, "tier": "high"},
    "RTX 5070 Ti": {"vram": 16, "tier": "high"},
    "RTX 5070": {"vram": 12, "tier": "mid"},
    "RTX 5060 Ti": {"vram": 16, "tier": "mid"},
    "RTX 5060": {"vram": 8, "tier": "entry"},
    "RTX 4090": {"vram": 24, "tier": "enthusiast"},
    "RTX 4080 SUPER": {"vram": 16, "tier": "high"},
    "RTX 4080": {"vram": 16, "tier": "high"},
    "RTX 4070 Ti SUPER": {"vram": 16, "tier": "high"},
    "RTX 4070 Ti": {"vram": 12, "tier": "mid"},
    "RTX 4070 SUPER": {"vram": 12, "tier": "mid"},
    "RTX 4070": {"vram": 12, "tier": "mid"},
    "RTX 4060 Ti": {"vram": 16, "tier": "mid"},
    "RTX 4060": {"vram": 8, "tier": "entry"},
    "RTX 3090 Ti": {"vram": 24, "tier": "enthusiast"},
    "RTX 3090": {"vram": 24, "tier": "enthusiast"},
    "RTX 3080 Ti": {"vram": 12, "tier": "high"},
    "RTX 3080": {"vram": 10, "tier": "high"},
    "RTX 3070 Ti": {"vram": 8, "tier": "mid"},
    "RTX 3070": {"vram": 8, "tier": "mid"},
    "RTX 3060": {"vram": 12, "tier": "mid"},
    "RTX 3050": {"vram": 8, "tier": "entry"},
}

# ---------------------------------------------------------------------------
# Model database (from canirun.ai + Unsloth)
# ---------------------------------------------------------------------------

MODELS_DB = {
    "Qwen3-Coder-Next": {
        "name": "Qwen3-Coder-Next",
        "repo": "unsloth/Qwen3-Coder-Next-GGUF",
        "params": "80B MoE",
        "type": "coding",
        "quants": {
            "UD-IQ1_S": {"size_gb": 21.5, "quality": "low", "bits": 1},
            "UD-IQ1_M": {"size_gb": 24.2, "quality": "medium", "bits": 2},
            "Q4_K_M": {"size_gb": 48.0, "quality": "good", "bits": 4},
            "Q5_K_M": {"size_gb": 56.0, "quality": "very_good", "bits": 5},
        },
        "use_cases": ["coding", "refactoring", "structured reasoning"],
    },
    "GLM-4.7-Flash": {
        "name": "GLM-4.7-Flash",
        "repo": "unsloth/GLM-4.7-Flash-GGUF",
        "params": "30B dense",
        "type": "general",
        "quants": {
            "UD-Q4_K_XL": {"size_gb": 16.3, "quality": "good", "bits": 4},
            "Q4_K_M": {"size_gb": 18.0, "quality": "good", "bits": 4},
            "Q5_K_M": {"size_gb": 21.0, "quality": "very_good", "bits": 5},
        },
        "use_cases": ["chat", "QA", "general tasks"],
    },
    "Qwen3-8B": {
        "name": "Qwen3-8B",
        "repo": "unsloth/Qwen3-8B-GGUF",
        "params": "8B dense",
        "type": "general",
        "quants": {
            "Q4_K_M": {"size_gb": 5.0, "quality": "good", "bits": 4},
            "Q5_K_M": {"size_gb": 5.8, "quality": "very_good", "bits": 5},
            "Q8_0": {"size_gb": 8.5, "quality": "excellent", "bits": 8},
        },
        "use_cases": ["fast responses", "lightweight tasks"],
    },
    "DeepSeek-Coder-V2": {
        "name": "DeepSeek-Coder-V2",
        "repo": "unsloth/DeepSeek-Coder-V2-GGUF",
        "params": "16B MoE",
        "type": "coding",
        "quants": {
            "Q4_K_M": {"size_gb": 8.0, "quality": "good", "bits": 4},
            "Q5_K_M": {"size_gb": 10.0, "quality": "very_good", "bits": 5},
        },
        "use_cases": ["code generation", "debugging"],
    },
    "MiniMax-M2.5": {
        "name": "MiniMax-M2.5",
        "repo": "unsloth/MiniMax-M2.5-GGUF",
        "params": "200B MoE",
        "type": "reasoning",
        "quants": {
            "UD-IQ1_S": {"size_gb": 55.0, "quality": "low", "bits": 1},
            "Q4_K_M": {"size_gb": 120.0, "quality": "good", "bits": 4},
        },
        "use_cases": ["reasoning", "complex tasks"],
    },
    "Llama-3.1-8B": {
        "name": "Llama 3.1 8B",
        "repo": "unsloth/Llama-3.1-8B-GGUF",
        "params": "8B dense",
        "type": "general",
        "quants": {
            "Q4_K_M": {"size_gb": 4.9, "quality": "good", "bits": 4},
            "Q5_K_M": {"size_gb": 5.7, "quality": "very_good", "bits": 5},
            "Q8_0": {"size_gb": 8.5, "quality": "excellent", "bits": 8},
        },
        "use_cases": ["general", "chat", "fast inference"],
    },
    "Phi-4": {
        "name": "Phi-4",
        "repo": "unsloth/Phi-4-GGUF",
        "params": "14B dense",
        "type": "general",
        "quants": {
            "Q4_K_M": {"size_gb": 8.5, "quality": "good", "bits": 4},
            "Q5_K_M": {"size_gb": 10.0, "quality": "very_good", "bits": 5},
        },
        "use_cases": ["reasoning", "math", "code"],
    },
    "Gemma-3-4B": {
        "name": "Gemma 3 4B",
        "repo": "unsloth/Gemma-3-4B-GGUF",
        "params": "4B dense",
        "type": "general",
        "quants": {
            "Q4_K_M": {"size_gb": 2.7, "quality": "good", "bits": 4},
            "Q8_0": {"size_gb": 4.5, "quality": "excellent", "bits": 8},
        },
        "use_cases": ["fast responses", "low memory", "lightweight"],
    },
}


# ---------------------------------------------------------------------------
# Hardware detection
# ---------------------------------------------------------------------------

def get_mac_hardware() -> Dict[str, Any]:
    """Detect Apple Silicon hardware using canirun.ai data model."""
    info = {
        "is_mac": False,
        "chip": "Unknown",
        "chip_family": "Unknown",
        "variant": "base",
        "cpu_cores": 0,
        "gpu_cores": 0,
        "ram_gb": 0,
        "ram_effective_gb": 0,
        "metal_available": False,
        "metal_device": "None",
    }

    if platform.system() != "Darwin":
        return info

    info["is_mac"] = True

    try:
        chip = subprocess.run(
            ["sysctl", "-n", "machdep.cpu.brand_string"],
            capture_output=True, text=True,
        ).stdout.strip()
        info["chip"] = chip if chip else "Apple Silicon"

        result = subprocess.run(
            ["sysctl", "-n", "hw.ncpu"],
            capture_output=True, text=True,
        )
        info["cpu_cores"] = int(result.stdout.strip()) if result.stdout else 0

        result = subprocess.run(
            ["sysctl", "-n", "hw.memsize"],
            capture_output=True, text=True,
        )
        ram_bytes = int(result.stdout.strip()) if result.stdout else 0
        info["ram_gb"] = ram_bytes // (1024 ** 3)

        # Detect chip family and variant
        for family in APPLE_SILICON:
            if family in chip:
                info["chip_family"] = family
                if "Ultra" in chip:
                    info["variant"] = "ultra"
                elif "Max" in chip:
                    info["variant"] = "max"
                elif "Pro" in chip:
                    info["variant"] = "pro"
                else:
                    info["variant"] = "base"
                break

        # Get GPU cores from database
        if info["chip_family"] != "Unknown":
            family_data = APPLE_SILICON.get(info["chip_family"], {})
            gpu_data = family_data.get("gpu_cores", 0)
            if isinstance(gpu_data, dict):
                info["gpu_cores"] = gpu_data.get(info["variant"], 0)
            else:
                info["gpu_cores"] = gpu_data

        # Check Metal support
        result = subprocess.run(
            ["system_profiler", "SPDisplaysDataType"],
            capture_output=True, text=True,
        )
        if "Apple" in result.stdout:
            info["metal_available"] = True
            for line in result.stdout.split("\n"):
                if "Metal" in line:
                    info["metal_device"] = line.split(":")[-1].strip()
                    break
                if "Apple" in line and "M" in line:
                    info["metal_device"] = line.split(":")[-1].strip()

    except Exception as e:
        info["error"] = str(e)

    # Effective RAM: reserve 4GB for system
    info["ram_effective_gb"] = max(info["ram_gb"] - 4, 0)
    return info


def get_nvidia_gpu() -> Optional[Dict[str, Any]]:
    """Detect NVIDIA GPU on Linux/Windows."""
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,memory.total", "--format=csv,noheader"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0 and result.stdout.strip():
            parts = result.stdout.strip().split(",")
            name = parts[0].strip()
            mem_str = parts[1].strip() if len(parts) > 1 else "0 MiB"
            vram_mb = int(mem_str.replace("MiB", "").strip())
            vram_gb = vram_mb // 1024

            # Match against known GPUs
            gpu_info = None
            for gpu_name, gpu_data in NVIDIA_GPUS.items():
                if gpu_name in name:
                    gpu_info = {"name": gpu_name, **gpu_data}
                    break

            if not gpu_info:
                gpu_info = {"name": name, "vram": vram_gb, "tier": "unknown"}

            return {
                "name": name,
                "vram_gb": vram_gb,
                "vram_mb": vram_mb,
                **gpu_info,
            }
    except (FileNotFoundError, subprocess.TimeoutExpired, Exception):
        pass
    return None


def detect_hardware() -> Dict[str, Any]:
    """Full hardware detection: Apple Silicon + NVIDIA."""
    mac = get_mac_hardware()
    nvidia = get_nvidia_gpu()

    return {
        "mac": mac,
        "nvidia": nvidia,
        "platform": platform.system(),
        "platform_release": platform.release(),
    }


# ---------------------------------------------------------------------------
# Model recommendations (canirun.ai logic)
# ---------------------------------------------------------------------------

def estimate_tok_per_sec(hardware: Dict[str, Any], model_size_gb: float, is_moe: bool = False) -> int:
    """Estimate tokens per second based on hardware and model size.

    Based on canirun.ai performance data.
    """
    mac = hardware.get("mac", {})
    nvidia = hardware.get("nvidia")

    if nvidia:
        # NVIDIA GPU estimation
        vram = nvidia.get("vram_gb", 8)
        tier = nvidia.get("tier", "entry")
        base_speeds = {
            "enthusiast": 80,
            "high": 50,
            "mid": 30,
            "entry": 15,
            "unknown": 20,
        }
        base = base_speeds.get(tier, 20)
        # Scale down for larger models
        if model_size_gb > 40:
            return max(int(base * 0.3), 2)
        elif model_size_gb > 20:
            return max(int(base * 0.5), 4)
        elif model_size_gb > 10:
            return max(int(base * 0.7), 8)
        return base

    if mac.get("is_mac"):
        # Apple Silicon estimation
        chip = mac.get("chip_family", "M1")
        variant = mac.get("variant", "base")
        ram = mac.get("ram_effective_gb", 8)

        # Base speed by chip generation
        gen_multiplier = {
            "M1": 1.0, "M2": 1.2, "M3": 1.4, "M4": 1.6, "M5": 1.8,
        }
        base = 20 * gen_multiplier.get(chip.replace(" Pro", "").replace(" Max", "").replace(" Ultra", ""), 1.0)

        # Variant multiplier
        variant_mult = {"base": 0.8, "pro": 1.0, "max": 1.3, "ultra": 1.6}
        base *= variant_mult.get(variant, 1.0)

        # Scale by model size
        if model_size_gb > 40:
            return max(int(base * 0.15), 2)
        elif model_size_gb > 20:
            return max(int(base * 0.3), 4)
        elif model_size_gb > 10:
            return max(int(base * 0.6), 8)
        elif model_size_gb > 5:
            return max(int(base * 0.8), 12)
        return max(int(base), 15)

    # Unknown hardware
    return 5


def get_llama_server_path() -> Optional[str]:
    """Find llama-server binary."""
    paths = [
        "/opt/homebrew/bin/llama-server",
        "/usr/local/bin/llama-server",
        str(Path.home() / ".local/bin/llama-server"),
    ]
    for p in paths:
        if Path(p).exists():
            return p
    result = subprocess.run(["which", "llama-server"], capture_output=True, text=True)
    if result.returncode == 0:
        return result.stdout.strip()
    return None


def check_cached_models() -> List[str]:
    """Check which models are cached locally."""
    cached = []
    cache_dir = MODELS_CACHE
    if not cache_dir.exists():
        return cached

    for model_key, model_info in MODELS_DB.items():
        repo = model_info.get("repo", "")
        # Check HuggingFace cache pattern: org__model__quant.gguf
        org, model_name = repo.split("/") if "/" in repo else ("", repo)
        pattern = f"{org}__{model_name}__"

        for f in cache_dir.rglob("*.gguf"):
            if pattern.replace("__", "_") in f.name or model_name.replace("-", "_") in f.name.lower():
                cached.append(model_key)
                break

    return cached


def recommend_models(hardware: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Recommend models using canirun.ai compatibility logic."""
    mac = hardware.get("mac", {})
    nvidia = hardware.get("nvidia")

    # Determine available memory
    if mac.get("is_mac"):
        available_gb = mac.get("ram_effective_gb", 0)
    elif nvidia:
        available_gb = nvidia.get("vram_gb", 0)
    else:
        available_gb = 0

    recommendations = []
    is_moe = False

    for model_key, model_info in MODELS_DB.items():
        params = model_info.get("params", "")
        is_moe = "MoE" in params

        # Find best quantization that fits
        best_quant = None
        best_size = float("inf")

        for quant_name, quant_info in model_info.get("quants", {}).items():
            size = quant_info["size_gb"]
            # Need 1.2x model size for context + overhead
            if size * 1.2 <= available_gb and size < best_size:
                best_quant = quant_name
                best_size = size

        if not best_quant:
            continue

        quant_info = model_info["quants"][best_quant]
        size_gb = quant_info["size_gb"]
        tok_sec = estimate_tok_per_sec(hardware, size_gb, is_moe)

        # Score: balance quality, speed, and fit
        score = tok_sec
        if quant_info["bits"] >= 4:
            score += 10
        if model_info["type"] == "coding":
            score += 5

        recommendations.append({
            "name": model_info["name"],
            "params": params,
            "type": model_info["type"],
            "quantization": best_quant,
            "size_gb": size_gb,
            "quality": quant_info["quality"],
            "estimated_tok_sec": tok_sec,
            "use_cases": model_info["use_cases"],
            "repo": model_info["repo"],
            "score": score,
        })

    return sorted(recommendations, key=lambda x: x["score"], reverse=True)


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def print_header(title: str) -> None:
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print(f"{'=' * 60}")


def print_hardware_info(hardware: Dict[str, Any]) -> None:
    print_header("DETECTED HARDWARE")

    mac = hardware.get("mac", {})
    nvidia = hardware.get("nvidia")

    if mac.get("is_mac"):
        print(f"  Chip:                 {mac.get('chip', 'Unknown')}")
        print(f"  Variant:              {mac.get('variant', 'N/A')}")
        print(f"  CPU Cores:            {mac.get('cpu_cores', 'N/A')}")
        print(f"  GPU Cores:            {mac.get('gpu_cores', 'N/A')}")
        print(f"  RAM:                  {mac.get('ram_gb', 0)} GB")
        print(f"  RAM Available:        {mac.get('ram_effective_gb', 0)} GB")
        print(f"  Metal Support:        {'Yes' if mac.get('metal_available') else 'No'}")
        if mac.get("metal_device") and mac["metal_device"] != "None":
            print(f"  Metal Device:         {mac['metal_device']}")
    elif nvidia:
        print(f"  GPU:                  {nvidia.get('name', 'Unknown')}")
        print(f"  VRAM:                 {nvidia.get('vram_gb', 0)} GB")
        print(f"  Tier:                 {nvidia.get('tier', 'Unknown')}")
    else:
        print(f"  Platform:             {hardware.get('platform', 'Unknown')}")
        print(f"  Note:                 Apple Silicon or NVIDIA GPU required for local inference")


def print_recommendations(recommendations: List[Dict[str, Any]], cached: List[str]) -> None:
    print_header("RECOMMENDED MODELS (via canirun.ai)")

    if not recommendations:
        print("  No models fit in available memory.")
        print("  Visit https://www.canirun.ai/ for more options.")
        return

    print(f"  {'#':<4} {'Model':<25} {'Size':<8} {'Quant':<12} {'tok/s':<8} {'Type':<12}")
    print(f"  {'-'*4} {'-'*25} {'-'*8} {'-'*12} {'-'*8} {'-'*12}")

    for i, model in enumerate(recommendations[:8], 1):
        cached_mark = " [cached]" if model["name"].replace(" ", "-").replace(".", "-") in [
            c.replace(" ", "-") for c in cached
        ] else ""
        print(
            f"  {i:<4} {model['name']:<25} {model['size_gb']:<8.1f} "
            f"{model['quantization']:<12} {model['estimated_tok_sec']:<8} "
            f"{model['type']:<12}{cached_mark}"
        )

    print(f"\n  Data source: https://www.canirun.ai/")
    print(f"  Model source: https://unsloth.ai/")


def print_system_check() -> None:
    print_header("SYSTEM CHECK")

    llama_path = get_llama_server_path()
    if llama_path:
        print(f"  [OK] llama-server: {llama_path}")
    else:
        print(f"  [MISSING] llama-server not found")
        print(f"           Install: brew install llama.cpp")

    if MODELS_CACHE.exists():
        print(f"  [OK] Model cache: {MODELS_CACHE}")
    else:
        print(f"  [WARN] Model cache not found: {MODELS_CACHE}")

    model_count = len(check_cached_models())
    print(f"  [INFO] Cached models: {model_count}")


def main() -> int:
    print("\n" + "=" * 60)
    print("  Tiny Local AI - Hardware Doctor")
    print("  Powered by canirun.ai")
    print("=" * 60)

    hardware = detect_hardware()
    cached = check_cached_models()
    recommendations = recommend_models(hardware)

    print_hardware_info(hardware)
    print_recommendations(recommendations, cached)
    print_system_check()

    print(f"\n{'=' * 60}")
    print("  Diagnostics complete")
    print(f"{'=' * 60}\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())

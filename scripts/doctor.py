#!/usr/bin/env python3
"""Hardware detection and model recommendation tool for Tiny Local AI."""

import json
import os
import platform
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

MODELS_CACHE = Path.home() / "Library/Caches/llama.cpp"

AVAILABLE_MODELS = {
    "Qwen3-Coder-Next": {
        "name": "Qwen3-Coder-Next",
        "file": "unsloth_Qwen3-Coder-Next-GGUF_UD-IQ1_S.gguf",
        "size_gb": 20,
        "params": "80B MoE",
        "quantization": "IQ1_S (1-bit)",
        "type": "coding",
        "tok_per_sec_base": 25,
        "use_cases": ["coding", "refactoring", "structured reasoning"],
    },
    "GLM-4.7-Flash": {
        "name": "GLM-4.7-Flash",
        "file": "unsloth_GLM-4.7-Flash-GGUF_UD-Q4_K_XL.gguf",
        "size_gb": 16,
        "params": "30B dense",
        "quantization": "Q4_K_XL (4-bit)",
        "type": "general",
        "tok_per_sec_base": 41,
        "use_cases": ["chat", "QA", "general tasks"],
    },
    "Qwen3-8B": {
        "name": "Qwen3-8B",
        "file": "Qwen3-8B-GGUF/Qwen3-8B-Q4_K_M.gguf",
        "size_gb": 5,
        "params": "8B dense",
        "quantization": "Q4_K_M",
        "type": "general",
        "tok_per_sec_base": 55,
        "use_cases": ["fast responses", "lightweight tasks"],
    },
    "DeepSeek-Coder-V2": {
        "name": "DeepSeek-Coder-V2",
        "file": "DeepSeek-Coder-V2-GGUF/DeepSeek-Coder-V2-Q4_K_M.gguf",
        "size_gb": 8,
        "params": "16B MoE",
        "quantization": "Q4_K_M",
        "type": "coding",
        "tok_per_sec_base": 35,
        "use_cases": ["code generation", "debugging"],
    },
}


def get_mac_hardware() -> Dict[str, Any]:
    """Detect Apple Silicon hardware details."""
    info = {
        "is_mac": False,
        "chip": "Unknown",
        "chip_family": "Unknown",
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
            capture_output=True,
            text=True,
        ).stdout.strip()
        info["chip"] = chip if chip else "Apple Silicon"

        result = subprocess.run(
            ["sysctl", "-n", "hw.ncpu"],
            capture_output=True,
            text=True,
        )
        info["cpu_cores"] = int(result.stdout.strip()) if result.stdout else 0

        result = subprocess.run(
            ["sysctl", "-n", "hw.memsize"],
            capture_output=True,
            text=True,
        )
        ram_bytes = int(result.stdout.strip()) if result.stdout else 0
        info["ram_gb"] = ram_bytes // (1024**3)

        result = subprocess.run(
            ["system_profiler", "SPDisplaysDataType"],
            capture_output=True,
            text=True,
        )
        if "Apple" in result.stdout:
            info["metal_available"] = True
            for line in result.stdout.split("\n"):
                if "Metal" in line:
                    info["metal_device"] = line.split(":")[-1].strip()
                    break
                if "Apple" in line:
                    info["metal_device"] = line.split(":")[-1].strip()

        if "M1" in chip or "M2" in chip or "M3" in chip or "M4" in chip:
            info["chip_family"] = chip.split()[0] if chip else "Apple Silicon"
            if "Max" in chip:
                info["gpu_cores"] = 24 if "M1" in chip else 28
            elif "Pro" in chip:
                info["gpu_cores"] = 14 if "M1" in chip else 18
            elif "Ultra" in chip:
                info["gpu_cores"] = 48

    except Exception as e:
        info["error"] = str(e)

    info["ram_effective_gb"] = info["ram_gb"] - 4
    return info


def get_llama_server_path() -> Optional[str]:
    """Find llama-server binary."""
    paths = [
        "/opt/homebrew/bin/llama-server",
        "/usr/local/bin/llama-server",
        Path.home() / ".local/bin/llama-server",
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
    if MODELS_CACHE.exists():
        for model_key, model_info in AVAILABLE_MODELS.items():
            model_path = MODELS_CACHE / model_info["file"]
            if model_path.exists():
                cached.append(model_key)
            else:
                parent = model_path.parent
                if parent.exists():
                    for f in parent.iterdir():
                        if f.is_file() and f.suffix == ".gguf":
                            cached.append(model_key)
                            break
    return cached


def get_model_size_gb(file_path: Path) -> float:
    """Get model file size in GB."""
    if file_path.exists():
        return file_path.stat().st_size / (1024**3)
    return 0.0


def recommend_models(
    hardware: Dict[str, Any], cached: List[str]
) -> List[Dict[str, Any]]:
    """Recommend models based on detected hardware."""
    recommendations = []
    ram = hardware.get("ram_effective_gb", hardware.get("ram_gb", 0))

    for model_key, model_info in AVAILABLE_MODELS.items():
        model_path = MODELS_CACHE / model_info["file"]
        size_gb = (
            get_model_size_gb(model_path)
            if model_path.exists()
            else model_info["size_gb"]
        )

        if size_gb > ram * 0.8:
            continue

        estimated_tok_sec = model_info["tok_per_sec_base"]
        if hardware.get("chip_family"):
            if "M1" in hardware["chip_family"]:
                estimated_tok_sec = int(model_info["tok_per_sec_base"] * 0.9)
            elif "M2" in hardware["chip_family"]:
                estimated_tok_sec = int(model_info["tok_per_sec_base"] * 1.0)
            elif "M3" in hardware["chip_family"] or "M4" in hardware["chip_family"]:
                estimated_tok_sec = int(model_info["tok_per_sec_base"] * 1.1)

        is_cached = model_key in cached
        score = 100
        if is_cached:
            score += 20
        if model_info["type"] == "coding":
            score += 10

        recommendations.append(
            {
                "name": model_info["name"],
                "size_gb": round(size_gb, 1),
                "params": model_info["params"],
                "quantization": model_info["quantization"],
                "type": model_info["type"],
                "estimated_tok_sec": estimated_tok_sec,
                "use_cases": model_info["use_cases"],
                "cached": is_cached,
                "score": score,
                "file": model_info["file"],
            }
        )

    return sorted(recommendations, key=lambda x: x["score"], reverse=True)


def print_header(title: str) -> None:
    """Print a section header."""
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print(f"{'=' * 60}")


def printHardwareInfo(hardware: Dict[str, Any]) -> None:
    """Print detected hardware information."""
    print_header("DETECTED HARDWARE")

    if not hardware.get("is_mac"):
        print("  ⚠️  Not running on Apple Silicon")
        print(f"  Platform: {platform.system()} {platform.release()}")
        return

    print(f"  Chip:                 {hardware.get('chip', 'Unknown')}")
    print(f"  CPU Cores:            {hardware.get('cpu_cores', 'N/A')}")
    print(f"  GPU Cores:            {hardware.get('gpu_cores', 'N/A')}")
    print(f"  RAM:                  {hardware.get('ram_gb', 0)} GB")
    print(f"  RAM Available:        {hardware.get('ram_effective_gb', 0)} GB")
    print(
        f"  Metal Support:        {'✅ Yes' if hardware.get('metal_available') else '❌ No'}"
    )
    if hardware.get("metal_device"):
        print(f"  Metal Device:         {hardware['metal_device']}")


def printModelRecommendations(recommendations: List[Dict[str, Any]]) -> None:
    """Print model recommendations."""
    print_header("RECOMMENDED MODELS")

    if not recommendations:
        print("  ❌ No models fit in available memory")
        return

    print("  Ranked by performance + fit:\n")

    for i, model in enumerate(recommendations, 1):
        cached_status = "✅ CACHED" if model["cached"] else "❌ NOT CACHED"
        print(f"  {i}. {model['name']}")
        print(f"     Size: {model['size_gb']}GB | Params: {model['params']}")
        print(f"     Quantization: {model['quantization']}")
        print(f"     Estimated: ~{model['estimated_tok_sec']} tok/sec")
        print(f"     Best for: {', '.join(model['use_cases'])}")
        print(f"     Status: {cached_status}")
        print()


def printCachedModels(cached: List[str]) -> None:
    """Print cached models."""
    print_header("CACHED MODELS")

    if not cached:
        print("  ❌ No models cached")
        print("  Run ./scripts/download-model.sh to download models")
        return

    print("  Available models:")
    for model_key in cached:
        model_info = AVAILABLE_MODELS.get(model_key, {})
        size = get_model_size_gb(MODELS_CACHE / model_info.get("file", ""))
        print(f"  • {model_key} ({size:.1f} GB)")


def printSystemCheck() -> None:
    """Print system health check."""
    print_header("SYSTEM CHECK")

    llama_path = get_llama_server_path()
    if llama_path:
        print(f"  ✅ llama-server: {llama_path}")
    else:
        print("  ❌ llama-server not found")
        print("  Install with: brew install llama.cpp")

    cache_path = MODELS_CACHE
    if cache_path.exists():
        print(f"  ✅ Model cache: {cache_path}")
    else:
        print(f"  ⚠️  Model cache not found: {cache_path}")

    model_count = len(check_cached_models())
    print(f"  📦 Cached models: {model_count}")


def main() -> int:
    """Main entry point."""
    print("\n" + "=" * 60)
    print("  🔍 Tiny Local AI - Hardware Doctor")
    print("=" * 60)

    hardware = get_mac_hardware()
    cached = check_cached_models()
    recommendations = recommend_models(hardware, cached)

    printHardwareInfo(hardware)
    printCachedModels(cached)
    printModelRecommendations(recommendations)
    printSystemCheck()

    print("\n" + "=" * 60)
    print("  ✅ Diagnostics complete")
    print("=" * 60 + "\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())

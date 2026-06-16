#!/usr/bin/env python3
"""Hardware detection and model recommendation for Tiny Local AI.

Uses canirun.ai hardware database and model compatibility data.
Data files in ../data/ can be updated via scripts/fetch-canirun-data.sh
"""

import json
import platform
import subprocess
import sys
from pathlib import Path
from typing import Any

DATA_DIR = Path(__file__).parent.parent / "data"
MODELS_CACHE = Path.home() / "Library/Caches/llama.cpp"

# Quality ranking for quantization selection (higher = better)
QUALITY_RANK = {
    "low": 1,
    "medium": 2,
    "good": 3,
    "very_good": 4,
    "excellent": 5,
}


def _load_json(name: str) -> dict:
    """Load a JSON data file from the data directory."""
    path = DATA_DIR / name
    if not path.exists():
        print(f"  [WARN] Data file not found: {path}", file=sys.stderr)
        return {}
    with open(path) as f:
        return json.load(f)


def _load_hardware_db() -> tuple:
    """Load hardware database. Returns (apple_silicon, nvidia_gpus)."""
    hw = _load_json("hardware.json")
    return hw.get("apple_silicon", {}), hw.get("nvidia_gpus", {})


def _load_models_db() -> dict:
    """Load model database."""
    return _load_json("models.json")


# ---------------------------------------------------------------------------
# Hardware detection
# ---------------------------------------------------------------------------


def get_mac_hardware(apple_silicon: dict) -> dict[str, Any]:
    """Detect Apple Silicon hardware."""
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

        # Detect chip family and variant — match longest prefix first
        # to avoid "M1" matching before "M1 Pro" / "M1 Max" / "M1 Ultra"
        matched_family = None
        matched_variant = "base"
        for family in sorted(apple_silicon.keys(), key=len, reverse=True):
            if family in chip:
                matched_family = family
                remainder = chip.replace(family, "").strip()
                if "Ultra" in remainder:
                    matched_variant = "ultra"
                elif "Max" in remainder:
                    matched_variant = "max"
                elif "Pro" in remainder:
                    matched_variant = "pro"
                else:
                    matched_variant = "base"
                break

        if matched_family:
            info["chip_family"] = matched_family
            info["variant"] = matched_variant
            family_data = apple_silicon[matched_family]
            gpu_data = family_data.get("gpu_cores", 0)
            if isinstance(gpu_data, dict):
                info["gpu_cores"] = gpu_data.get(matched_variant, 0)
            else:
                info["gpu_cores"] = gpu_data

        # Check Metal support
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
                if "Apple" in line and "M" in line:
                    info["metal_device"] = line.split(":")[-1].strip()

    except Exception as e:
        info["error"] = str(e)

    info["ram_effective_gb"] = max(info["ram_gb"] - 4, 0)
    return info


def get_nvidia_gpu(nvidia_gpus: dict) -> dict[str, Any] | None:
    """Detect NVIDIA GPU on Linux/Windows."""
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,memory.total", "--format=csv,noheader"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0 and result.stdout.strip():
            # nvidia-smi emits one line per GPU; .split(",") on the whole
            # blob collapses multi-GPU rows incorrectly. Take the first line.
            first_line = result.stdout.strip().splitlines()[0]
            parts = first_line.split(",")
            name = parts[0].strip()
            mem_str = parts[1].strip() if len(parts) > 1 else "0 MiB"
            vram_mb = int(mem_str.replace("MiB", "").strip())
            vram_gb = vram_mb // 1024

            # Match against known GPUs — longest prefix first
            gpu_info = None
            for gpu_name in sorted(nvidia_gpus.keys(), key=len, reverse=True):
                if gpu_name in name:
                    gpu_info = {"name": gpu_name, **nvidia_gpus[gpu_name]}
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


def detect_hardware() -> dict[str, Any]:
    """Full hardware detection: Apple Silicon + NVIDIA."""
    apple_silicon, nvidia_gpus = _load_hardware_db()
    mac = get_mac_hardware(apple_silicon)
    nvidia = get_nvidia_gpu(nvidia_gpus)

    return {
        "mac": mac,
        "nvidia": nvidia,
        "platform": platform.system(),
        "platform_release": platform.release(),
    }


# ---------------------------------------------------------------------------
# Model recommendations
# ---------------------------------------------------------------------------


def estimate_tok_per_sec(hardware: dict[str, Any], model_size_gb: float) -> int:
    """Estimate tokens per second based on hardware and model size."""
    mac = hardware.get("mac", {})
    nvidia = hardware.get("nvidia")

    if nvidia:
        tier = nvidia.get("tier", "entry")
        base_speeds = {
            "enthusiast": 80,
            "high": 50,
            "mid": 30,
            "entry": 15,
            "unknown": 20,
        }
        base = base_speeds.get(tier, 20)
        if model_size_gb > 40:
            return max(int(base * 0.3), 2)
        elif model_size_gb > 20:
            return max(int(base * 0.5), 4)
        elif model_size_gb > 10:
            return max(int(base * 0.7), 8)
        return base

    if mac.get("is_mac"):
        chip = mac.get("chip_family", "M1")
        variant = mac.get("variant", "base")

        gen_multiplier = {"M1": 1.0, "M2": 1.2, "M3": 1.4, "M4": 1.6, "M5": 1.8}
        base_chip = chip.replace(" Pro", "").replace(" Max", "").replace(" Ultra", "")
        base = 20 * gen_multiplier.get(base_chip, 1.0)

        variant_mult = {"base": 0.8, "pro": 1.0, "max": 1.3, "ultra": 1.6}
        base *= variant_mult.get(variant, 1.0)

        if model_size_gb > 40:
            return max(int(base * 0.15), 2)
        elif model_size_gb > 20:
            return max(int(base * 0.3), 4)
        elif model_size_gb > 10:
            return max(int(base * 0.6), 8)
        elif model_size_gb > 5:
            return max(int(base * 0.8), 12)
        return max(int(base), 15)

    return 5


def get_llama_server_path() -> str | None:
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


def check_cached_models(models_db: dict) -> list[str]:
    """Check which models are cached locally. Single pass over directory."""
    cached = []
    if not MODELS_CACHE.exists():
        return cached

    # Single pass: collect all .gguf filenames
    gguf_names = [f.name.lower() for f in MODELS_CACHE.rglob("*.gguf") if f.is_file()]

    for model_key, model_info in models_db.items():
        repo = model_info.get("repo", "")
        if "/" not in repo:
            # Repos without an org prefix can't be matched against cached
            # filenames with a stable pattern; skip to avoid false positives.
            continue
        org, model_name = repo.split("/", 1)
        # Lowercase the pattern to match the lowercased gguf_names
        pattern = f"{org}__{model_name}__".replace("__", "_").lower()
        model_slug = model_name.replace("-", "_").lower()

        for name in gguf_names:
            if pattern in name or model_slug in name:
                cached.append(model_key)
                break

    return cached


def recommend_models(hardware: dict[str, Any], models_db: dict) -> list[dict[str, Any]]:
    """Recommend models using canirun.ai compatibility logic.

    Selects the best quality quantization that fits in available memory,
    not the smallest one.
    """
    mac = hardware.get("mac", {})
    nvidia = hardware.get("nvidia")

    if mac.get("is_mac"):
        available_gb = mac.get("ram_effective_gb", 0)
    elif nvidia:
        available_gb = nvidia.get("vram_gb", 0)
    else:
        available_gb = 0

    recommendations = []

    for model_key, model_info in models_db.items():
        # Find the best quality quantization that fits
        best_quant = None
        best_quality_rank = -1
        best_size = 0.0

        for quant_name, quant_info in model_info.get("quants", {}).items():
            size = quant_info["size_gb"]
            # Need 1.2x model size for context + overhead
            if size * 1.2 > available_gb:
                continue
            q_rank = QUALITY_RANK.get(quant_info.get("quality", "low"), 0)
            if q_rank > best_quality_rank or (q_rank == best_quality_rank and size < best_size):
                best_quant = quant_name
                best_quality_rank = q_rank
                best_size = size

        if not best_quant:
            continue

        quant_info = model_info["quants"][best_quant]
        size_gb = quant_info["size_gb"]
        tok_sec = estimate_tok_per_sec(hardware, size_gb)

        score = tok_sec
        if quant_info["bits"] >= 4:
            score += 10
        if model_info["type"] in ("coding", "reasoning"):
            score += 5

        recommendations.append(
            {
                "key": model_key,
                "name": model_info["name"],
                "params": model_info.get("params", ""),
                "type": model_info["type"],
                "quantization": best_quant,
                "size_gb": size_gb,
                "quality": quant_info["quality"],
                "estimated_tok_sec": tok_sec,
                "use_cases": model_info["use_cases"],
                "repo": model_info["repo"],
                "score": score,
            }
        )

    return sorted(recommendations, key=lambda x: x["score"], reverse=True)


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------


def print_header(title: str) -> None:
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print(f"{'=' * 60}")


def print_hardware_info(hardware: dict[str, Any]) -> None:
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
        print("  Note:                 Apple Silicon or NVIDIA GPU required for local inference")


def print_recommendations(recommendations: list[dict[str, Any]], cached: list[str]) -> None:
    print_header("RECOMMENDED MODELS (via canirun.ai)")

    if not recommendations:
        print("  No models fit in available memory.")
        print("  Visit https://www.canirun.ai/ for more options.")
        return

    # Paths are printed in repo-root-relative form (assume CWD is repo root,
    # which matches the convention used throughout AGENTS.md).
    download_script = "./scripts/download-model.sh"
    start_script = "./scripts/start-llm.sh"

    print(f"  {'#':<4} {'Model':<25} {'Size':<8} {'Quant':<12} {'tok/s':<8} {'Type':<12}")
    print(f"  {'-' * 4} {'-' * 25} {'-' * 8} {'-' * 12} {'-' * 8} {'-' * 12}")

    for i, model in enumerate(recommendations[:8], 1):
        cached_mark = " [cached]" if model.get("key") in cached else ""
        print(
            f"  {i:<4} {model['name']:<25} {model['size_gb']:<8.1f} "
            f"{model['quantization']:<12} {model['estimated_tok_sec']:<8} "
            f"{model['type']:<12}{cached_mark}"
        )
        if model.get("key") in cached:
            # Use simple model key to match start-llm.sh's simple-name branch
            print(f"       ✓ Already cached — run: {start_script} {model['key']}")
        else:
            print(f"       verify → {download_script} --list {model['repo']}")
            print(f"       download → {download_script} {model['repo']}:{model['quantization']}")

    print("\n  Data source: https://www.canirun.ai/")
    print("  Model source: https://unsloth.ai/")


def print_system_check(cached: list[str]) -> None:
    print_header("SYSTEM CHECK")

    llama_path = get_llama_server_path()
    if llama_path:
        print(f"  [OK] llama-server: {llama_path}")
    else:
        print("  [MISSING] llama-server not found")
        print("           Install: brew install llama.cpp")

    if MODELS_CACHE.exists():
        print(f"  [OK] Model cache: {MODELS_CACHE}")
    else:
        print(f"  [WARN] Model cache not found: {MODELS_CACHE}")

    print(f"  [INFO] Cached models: {len(cached)}")


def main() -> int:
    print("\n" + "=" * 60)
    print("  Tiny Local AI - Hardware Doctor")
    print("  Powered by canirun.ai")
    print("=" * 60)

    models_db = _load_models_db()
    hardware = detect_hardware()
    cached = check_cached_models(models_db)
    recommendations = recommend_models(hardware, models_db)

    print_hardware_info(hardware)
    print_recommendations(recommendations, cached)
    print_system_check(cached)

    print(f"\n{'=' * 60}")
    print("  Diagnostics complete")
    print(f"{'=' * 60}\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())

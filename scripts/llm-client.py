#!/usr/bin/env python3
"""CLI client for local LLM server."""

import argparse
import os
import sys
from pathlib import Path

DEFAULT_URL = os.getenv("LLM_SERVER_URL", "http://localhost:8000/v1")
DEFAULT_MODEL = os.getenv("LLM_MODEL", "qwen")


def get_config_path() -> Path:
    config_dir = Path.home() / ".config" / "tiny-local-ai"
    config_dir.mkdir(parents=True, exist_ok=True)
    return config_dir / "config"


def load_config() -> dict[str, str]:
    config_path = get_config_path()
    config = {}
    if config_path.exists():
        with open(config_path) as f:
            for line in f:
                line = line.strip()
                if line and "=" in line:
                    key, value = line.split("=", 1)
                    config[key.strip()] = value.strip()
    return config


def save_config(url: str, model: str):
    config_path = get_config_path()
    with open(config_path, "w") as f:
        f.write(f"url={url}\n")
        f.write(f"model={model}\n")


def main():
    parser = argparse.ArgumentParser(description="Local LLM CLI Client")
    parser.add_argument("prompt", nargs="?", help="Prompt to send to the model")
    parser.add_argument("-m", "--model", default=DEFAULT_MODEL, help="Model name")
    parser.add_argument("-u", "--url", default=DEFAULT_URL, help="Server URL")
    parser.add_argument("-s", "--stream", action="store_true", help="Stream response")
    parser.add_argument(
        "-c", "--config", action="store_true", help="Save as default config"
    )
    parser.add_argument("--system", help="System prompt")
    args = parser.parse_args()

    if args.config:
        save_config(args.url, args.model)
        print(f"Config saved: url={args.url}, model={args.model}")
        return

    from openai import OpenAI

    client = OpenAI(base_url=args.url, api_key="sk-no-key")

    messages = []
    if args.system:
        messages.append({"role": "system", "content": args.system})
    messages.append({"role": "user", "content": args.prompt})

    try:
        if args.stream:
            response = client.chat.completions.create(
                model=args.model,
                messages=messages,
                stream=True,
            )
            print(">>> ", end="", flush=True)
            for chunk in response:
                if chunk.choices and chunk.choices[0].delta.content:
                    print(chunk.choices[0].delta.content, end="", flush=True)
            print()
        else:
            response = client.chat.completions.create(
                model=args.model,
                messages=messages,
            )
            content = response.choices[0].message.content
            if content:
                print(content)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

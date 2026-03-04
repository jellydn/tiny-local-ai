# AGENTS.md - Agent Coding Guidelines

This file provides guidelines for agentic coding agents operating in this repository.

## Project Overview

**Tiny Local AI** - Run local LLM on MacBook A, access from MacBook B over LAN.

- **Languages**: Python (CLI client, dashboard), Bash (server scripts)
- **Dependencies**: llama.cpp, openai Python package
- **No formal test suite** - This is a simple script collection

---

## Build / Run Commands

### Python Scripts

```bash
# Install dependencies
pip install openai

# Run CLI client
python scripts/llm-client.py "your prompt"

# Run with streaming
python scripts/llm-client.py -s "your prompt"

# Save default config
python scripts/llm-client.py --config -u http://localhost:8000/v1 -m qwen

# Run dashboard
python scripts/serve-dashboard.py

# Run dashboard on custom port
python scripts/serve-dashboard.py -p 9000
```

### Bash Scripts

```bash
# Start server (requires llama-server binary in PATH or scripts/)
./scripts/start-llm.sh qwen3-coder-next

# With custom port
PORT=8080 ./scripts/start-llm.sh qwen

# Stop server
./scripts/stop-llm.sh
```

### Linting (Python)

```bash
# Run ruff linter
ruff check scripts/

# Auto-fix issues
ruff check scripts/ --fix
```

---

## Code Style Guidelines

### General Principles

- **Keep it simple** - This is a lightweight tool collection, not an enterprise app
- **Self-documenting code** - Use clear names, add comments for non-obvious logic
- **Fail fast with clear messages** - User-facing errors should explain what went wrong and how to fix it
- **No over-engineering** - Avoid unnecessary abstractions

### Python Style

1. **Imports**
   - Standard library first, then third-party
   - Use absolute imports (`from openai import OpenAI`)
   - Group: stdlib, third-party, local

   ```python
   import argparse
   import os
   import sys
   from pathlib import Path

   from openai import OpenAI
   ```

2. **Type Hints**
   - Use type hints for function signatures
   - Use `dict` not `Dict`, `list` not `List` (Python 3.9+)

   ```python
   def get_config_path() -> Path:
       ...

   def load_config() -> dict[str, str]:
       ...
   ```

3. **Naming**
   - `snake_case` for functions and variables
   - `PascalCase` for classes (if any)
   - CONSTANTS in UPPER_SNAKE_CASE

4. **Formatting**
   - Max line length: 100 characters
   - Use 4 spaces for indentation
   - Use f-strings for formatting
   - One blank line between top-level definitions

5. **Error Handling**
   - Catch specific exceptions, not bare `except:`
   - Print errors to stderr with `print(f"Error: {e}", file=sys.stderr)`
   - Exit with code 1 on fatal errors

   ```python
   try:
       response = client.chat.completions.create(...)
   except Exception as e:
       print(f"Error: {e}", file=sys.stderr)
       sys.exit(1)
   ```

6. **Shebang**
   - Python scripts: `#!/usr/bin/env python3`
   - Add module docstring at top

   ```python
   #!/usr/bin/env python3
   """Short description of what this script does."""
   ```

### Bash Style

1. **Shebang and Options**

   ```bash
   #!/usr/bin/env bash

   set -e  # Exit on error
   set -u  # Exit on undefined variable
   ```

2. **Variables**
   - Use `SCREAMING_SNAKE_CASE` for constants
   - Use `camelCase` or `snake_case` for local variables
   - Always quote variables: `"$VAR}"`, not `$VAR`

3. **Functions**
   - Use `local` for function-scope variables
   - Use descriptive function names with underscores

   ```bash
   detect_ram() {
       local RAM
       RAM=$(sysctl -n hw.memsize 2>/dev/null || echo "34359738368")
       ...
   }
   ```

4. **Error Messages**
   - Print errors to stderr: `echo "Error: message" >&2`
   - Exit with code 1 on failure

5. **Indentation**
   - Use tabs for bash scripts (as shown in existing files)

---

## File Organization

```
.
├── scripts/
│   ├── start-llm.sh      # Server startup (executable)
│   ├── stop-llm.sh       # Server shutdown (executable)
│   ├── llm-client.py     # CLI client
│   └── serve-dashboard.py # Web dashboard
├── models/                # GGUF model files (gitignored)
├── .gitignore
├── README.md
└── LICENSE
```

---

## Documentation

- **README.md** - User-facing documentation, quick start
- **Inline comments** - Explain non-obvious logic only
- **Error messages** - Should guide user to solution

---

## Git Conventions

- Use meaningful commit messages
- Keep commits small and focused
- No need for formal PR process (personal project)

---

## Security Considerations

- Never commit API keys or secrets
- Use environment variables for configuration
- Models directory is gitignored

---

## Dependencies

- Keep dependencies minimal
- Python: only `openai` (for OpenAI-compatible API client)
- No runtime needed beyond standard library (for scripts)

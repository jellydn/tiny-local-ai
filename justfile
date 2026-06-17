lint:
    uv run ruff check scripts/

fix:
    uv run ruff check scripts/ --fix

format:
    uv run ruff format scripts/

format-check:
    uv run ruff format scripts/ --check

doctor:
    uv run python scripts/doctor.py

benchmark categories="coding":
    uv run python scripts/benchmark.py --categories {{categories}}

ci: lint format-check

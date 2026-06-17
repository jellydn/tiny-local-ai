#!/usr/bin/env bash
# Scrape visible model identifiers from canirun.ai (one-shot)
# Usage: ./scripts/scrape-canirun-list.sh [--out PATH]
#
# Drives headless Chromium (via playwright, loaded on-demand through
# `uv run --with playwright`) to load https://canirun.ai/, waits for the SPA
# to hydrate, then extracts AI model-family identifier strings from the
# rendered DOM. Output: one JSON object per model on stdout, formatted as
#   {"name":"<name>","family":"<family>"}
# Use --out PATH to write to a file instead of stdout.
#
# Note: this is a one-shot diagnostic tool. It does NOT modify data/*.json.
# Validate any extracted slug with `./scripts/download-model.sh --list <slug>`
# before adding it to data/models.json.

set -euo pipefail

OUT_PATH=""
while [[ $# -gt 0 ]]; do
	case "$1" in
		--out) OUT_PATH="$2"; shift 2 ;;
		-h|--help)
			echo "Usage: ./scripts/scrape-canirun-list.sh [--out PATH]"
			exit 0 ;;
		*)
			echo "[scrape-canirun-list] unknown arg: $1" >&2
			exit 2 ;;
	esac
done

CHROME_BIN="${CHROME_BIN:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
if [[ ! -x "$CHROME_BIN" ]]; then
	echo "[ERROR] Chrome binary not found at: $CHROME_BIN" >&2
	echo "        Override with: CHROME_BIN=/path/to/chrome $0" >&2
	exit 1
fi
export CHROME_BIN

PYSCRIPT_FILE=$(mktemp "${TMPDIR:-/tmp}/scrape-canirun-list.XXXXXX.py")
trap 'rm -f "$PYSCRIPT_FILE"' EXIT

cat > "$PYSCRIPT_FILE" <<'PYEOF'
import asyncio, json, os, re, sys
from playwright.async_api import async_playwright

CHROME = os.environ["CHROME_BIN"]
URL = "https://canirun.ai/"

# AI model families we expect to see in canirun.ai's render
FAMILIES = [
	"Llama", "Qwen", "DeepSeek", "Gemma", "Phi", "Mistral", "GLM",
	"Codestral", "Yi", "Command", "Mixtral", "InternLM", "Baichuan",
	"Cohere", "StarCoder", "CodeLlama", "Granite", "OLMo", "DBRX",
	"SmolLM", "Pixtral", "Hermes",
]

# Match a family-prefixed identifier, e.g.:
#   "Llama 3.3 8B", "Qwen3-Coder-Next", "DeepSeek-R1-Distill-Llama-8B",
#   "Phi 4 mini Instruct", "Gemma 3n E4B"
NAME_RE = re.compile(
	r"\b(" + "|".join(re.escape(f) for f in FAMILIES) + r")"
	r"(?:[\s\-.]+[A-Za-z0-9\-]+){1,6}\b",
	re.IGNORECASE,
)

# Tokens that hint this is just UI prose, not a model name
NOISE = (
	"learn", "more", "read", "see", "all", "category", "filter", "sort",
	"models", "result", "results", "search", "available", "compatible",
)


def plausible(name: str) -> bool:
	if len(name) < 4 or len(name) > 80:
		return False
	n_low = name.lower()
	for w in NOISE:
		if f" {w} " in f" {n_low} ":
			return False
	# require at least one sub-token beyond the family itself — "Llama" alone
	# is too generic to be a model identifier
	stripped = name
	for f in FAMILIES:
		stripped = re.sub(rf"^{re.escape(f)}\b", "", stripped, flags=re.IGNORECASE).strip()
	if not stripped:
		return False
	# cap sentence-like captures (would imply the match bled into prose)
	if " " in stripped and len(stripped.split()) > 5:
		return False
	return True


async def main() -> None:
	async with async_playwright() as p:
		try:
			browser = await p.chromium.launch(
				headless=True,
				args=["--no-sandbox", "--disable-dev-shm-usage"],
			)
			print("[scrape-py] using playwright bundled chromium", file=sys.stderr)
		except Exception as e:
			print(
				f"[scrape-py] playwright bundled launch failed ({e}); "
				f"falling back to system Chrome at {CHROME}",
				file=sys.stderr,
			)
			browser = await p.chromium.launch(
				executable_path=CHROME,
				headless=True,
				args=["--no-sandbox", "--disable-dev-shm-usage"],
			)
		page = await (await browser.new_context()).new_page()
		await page.goto(URL, wait_until="networkidle", timeout=60_000)
		try:
			await page.wait_for_selector(
				"select, button, [data-model]", timeout=15_000
			)
		except Exception as e:
			print(f"[scrape-py] selector wait timed out: {e}", file=sys.stderr)
		await asyncio.sleep(1)

		blobs = await page.evaluate("""
() => {
  const out = [];
  const sel = 'select, option, h1, h2, h3, h4, button, [role=button], li, [data-model], [data-name], [data-id]';
  for (const el of document.querySelectorAll(sel)) {
    out.push({
      tag: el.tagName,
      text: (el.textContent || '').trim().slice(0, 400),
      value: el.getAttribute('data-name')
        || el.getAttribute('data-model')
        || el.getAttribute('data-id')
        || el.getAttribute('value')
        || '',
    });
  }
  return out;
}
""")
		seen: set[str] = set()
		rows: list[dict] = []
		for b in blobs:
			joined = (b.get("text") or "") + " " + (b.get("value") or "")
			for m in NAME_RE.finditer(joined):
				n = re.sub(r"\s+", " ", m.group(0).strip())
				if not plausible(n):
					continue
				key = n.lower()
				if key in seen:
					continue
				seen.add(key)
				fam = next(f for f in FAMILIES if f.lower() in n.lower())
				rows.append({"name": n, "family": fam.lower()})
		for r in rows:
			print(json.dumps(r, ensure_ascii=False))
		print(f"[scrape-py] total extracted: {len(rows)}", file=sys.stderr)
		await browser.close()


asyncio.run(main())
PYEOF

echo "[scrape-canirun-list] launching headless Chromium" >&2
raw=$(uv run --with playwright python "$PYSCRIPT_FILE" 2> /tmp/scrape-canirun-list.stderr || true)

if [[ -z "$raw" ]]; then
	echo "[scrape-canirun-list] no rows extracted; stderr:" >&2
	cat /tmp/scrape-canirun-list.stderr >&2 || true
	exit 1
fi

unique=$(printf '%s\n' "$raw" | sort -u | wc -l | tr -d ' ')
echo "[scrape-canirun-list] extracted $unique unique identifiers" >&2

if [[ -n "$OUT_PATH" ]]; then
	printf '%s\n' "$raw" | sort -u > "$OUT_PATH"
	echo "[scrape-canirun-list] wrote $OUT_PATH" >&2
else
	printf '%s\n' "$raw" | sort -u
fi

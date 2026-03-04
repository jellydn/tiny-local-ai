#!/usr/bin/env python3
"""Simple web dashboard for LLM server status."""

import argparse
import json
import os
import sys
import time
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.request import urlopen
from urllib.error import URLError

DEFAULT_URL = os.getenv("LLM_SERVER_URL", "http://localhost:8000")

HTML_TEMPLATE = """<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta http-equiv="refresh" content="5">
    <title>Tiny Local AI Dashboard</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: #1a1a2e;
            color: #eee;
        }}
        h1 {{ color: #00d9ff; margin-bottom: 30px; }}
        .card {{
            background: #16213e;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 20px;
            border: 1px solid #0f3460;
        }}
        .status {{ display: flex; align-items: center; gap: 10px; }}
        .status-dot {{
            width: 12px; height: 12px; border-radius: 50%;
        }}
        .online {{ background: #00ff88; box-shadow: 0 0 10px #00ff88; }}
        .offline {{ background: #ff4444; }}
        .metric {{
            display: flex;
            justify-content: space-between;
            padding: 10px 0;
            border-bottom: 1px solid #0f3460;
        }}
        .metric:last-child {{ border-bottom: none; }}
        .label {{ color: #888; }}
        .value {{ color: #00d9ff; font-weight: bold; }}
        .error {{ color: #ff4444; padding: 20px; text-align: center; }}
        .info {{ font-size: 12px; color: #666; margin-top: 20px; }}
    </style>
</head>
<body>
    <h1>🤖 Tiny Local AI Dashboard</h1>
    
    <div class="card">
        <div class="status">
            <div class="status-dot {status_class}"></div>
            <span>{status_text}</span>
        </div>
    </div>
    
    {content}
    
    <div class="info">Auto-refresh every 5 seconds</div>
    
    <script>
        // Auto-refresh is handled by meta refresh
    </script>
</body>
</html>
"""


def check_server(url: str) -> dict:
    result = {
        "online": False,
        "model": "Unknown",
        "context": 0,
    }

    try:
        with urlopen(f"{url}/v1/models", timeout=5) as resp:
            data = json.load(resp)
            if "data" in data and len(data["data"]) > 0:
                result["online"] = True
                model = data["data"][0]
                result["model"] = model.get("id", "Unknown")

                # Extract context size from model metadata
                meta = model.get("meta", {})
                if "n_ctx_train" in meta:
                    ctx = meta["n_ctx_train"]
                    result["context"] = f"{ctx:,}"
    except URLError:
        pass
    except Exception:
        pass

    return result


def get_gpu_info() -> dict:
    try:
        import subprocess

        result = subprocess.run(
            ["system_profiler", "SPDisplaysDataType"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if "Apple" in result.stdout:
            return {"type": "Apple Silicon (Metal)", "available": True}
    except Exception:
        pass
    return {"type": "Unknown", "available": False}


def main():
    parser = argparse.ArgumentParser(description="LLM Server Dashboard")
    parser.add_argument("-u", "--url", default=DEFAULT_URL, help="Server URL")
    parser.add_argument("-p", "--port", type=int, default=8080, help="Dashboard port")
    args = parser.parse_args()

    server_info = check_server(args.url)
    gpu_info = get_gpu_info()

    if server_info["online"]:
        status_class = "online"
        status_text = "Server Online"
        content = f"""
        <div class="card">
            <div class="metric">
                <span class="label">Model</span>
                <span class="value">{server_info["model"]}</span>
            </div>
            <div class="metric">
                <span class="label">Context Size</span>
                <span class="value">{server_info["context"]} tokens</span>
            </div>
            <div class="metric">
                <span class="label">GPU</span>
                <span class="value">{gpu_info["type"]}</span>
            </div>
            <div class="metric">
                <span class="label">Server URL</span>
                <span class="value">{args.url}/v1</span>
            </div>
        </div>
        """
    else:
        status_class = "offline"
        status_text = "Server Offline"
        content = (
            '<div class="card"><div class="error">Server is not responding</div></div>'
        )

    html = HTML_TEMPLATE.format(
        status_class=status_class, status_text=status_text, content=content
    )

    class Handler(SimpleHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/" or self.path == "/index.html":
                self.send_response(200)
                self.send_header("Content-type", "text/html")
                self.end_headers()
                self.wfile.write(html.encode())
            else:
                self.send_response(404)
                self.end_headers()

        def log_message(self, format, *args):
            pass

    addr = ("0.0.0.0", args.port)
    print(f"Dashboard running at http://localhost:{args.port}")
    print(f"Server: {args.url}")

    try:
        HTTPServer(addr, Handler).serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        sys.exit(0)


if __name__ == "__main__":
    main()

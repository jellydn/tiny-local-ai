#!/usr/bin/env bash

TMUX_SESSION="llm-server"
PORT="${PORT:-8000}"

stopped=false

# Try stopping tmux session
if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
	echo "Stopping LLM server (tmux)..."
	tmux kill-session -t "$TMUX_SESSION"
	stopped=true
fi

# Try stopping background process (llama-server on port)
if command -v lsof &>/dev/null; then
	PIDS=$(lsof -ti :$PORT 2>/dev/null)
	if [ -n "$PIDS" ]; then
		echo "Stopping LLM server (background process on port $PORT)..."
		echo "$PIDS" | xargs kill -9 2>/dev/null || true
		stopped=true
	fi
fi

if [ "$stopped" = true ]; then
	echo "Server stopped."
else
	echo "No running server found (session: $TMUX_SESSION, port: $PORT)"
fi

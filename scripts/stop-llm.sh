#!/usr/bin/env bash

TMUX_SESSION="llm-server"

if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
	echo "Stopping LLM server..."
	tmux kill-session -t "$TMUX_SESSION"
	echo "Server stopped."
else
	echo "No running server found (session: $TMUX_SESSION)"
fi

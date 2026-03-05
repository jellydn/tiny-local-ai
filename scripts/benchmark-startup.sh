#!/usr/bin/env bash

set -e
set -u

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PORT="${PORT:-8000}"
MODEL="${1:-qwen3-coder-next}"
ITERATIONS="${2:-3}"

echo -e "${BLUE}=== LLM Startup Benchmarker ===${NC}"
echo ""
echo "Model: $MODEL"
echo "Port: $PORT"
echo "Iterations: $ITERATIONS"
echo ""

# Track results
declare -a times
total_time=0

for i in $(seq 1 "$ITERATIONS"); do
	echo -e "${YELLOW}[${i}/${ITERATIONS}]${NC} Starting model..."

	# Stop any existing server
	if pgrep -f "llama-server.*--port $PORT" >/dev/null 2>&1; then
		pkill -f "llama-server.*--port $PORT" || true
		sleep 1
	fi

	# Measure startup time
	start_time=$(date +%s%3N)

	# Start the server
	./scripts/start-llm.sh "$MODEL" --port "$PORT" >/dev/null 2>&1 &
	SERVER_PID=$!

	# Wait for API to be ready
	server_ready=0
	max_wait=120 # 120 seconds timeout
	elapsed=0

	while [ $elapsed -lt $max_wait ]; do
		if curl -s http://localhost:$PORT/health 2>/dev/null | grep -q "ok"; then
			server_ready=1
			break
		fi
		sleep 1
		elapsed=$((elapsed + 1))
	done

	end_time=$(date +%s%3N)
	elapsed_time=$((end_time - start_time))

	if [ $server_ready -eq 1 ]; then
		echo -e "${GREEN}✓${NC} Ready in ${elapsed_time}ms"
		times+=("$elapsed_time")
		total_time=$((total_time + elapsed_time))
	else
		echo -e "${RED}✗${NC} Timeout after ${max_wait}s"
	fi

	# Stop for next iteration
	if [ -n "${SERVER_PID:-}" ]; then
		kill "$SERVER_PID" 2>/dev/null || true
	fi
	sleep 1
done

echo ""
echo -e "${BLUE}=== Results ===${NC}"
echo ""

if [ ${#times[@]} -gt 0 ]; then
	avg_time=$((total_time / ${#times[@]}))
	min_time=${times[0]}
	max_time=${times[0]}

	for t in "${times[@]}"; do
		if [ "$t" -lt "$min_time" ]; then
			min_time=$t
		fi
		if [ "$t" -gt "$max_time" ]; then
			max_time=$t
		fi
	done

	echo "Successful starts: ${#times[@]}/${ITERATIONS}"
	echo "Average startup:  ${avg_time}ms"
	echo "Min startup:      ${min_time}ms"
	echo "Max startup:      ${max_time}ms"
	echo "Total time:       $((total_time / 1000))s"
else
	echo -e "${RED}No successful starts${NC}"
	exit 1
fi

#!/bin/bash

# Start the Apibara indexer

echo "Starting Apibara indexer..."
deno run --allow-net --allow-env --allow-read index.ts &
# deno run --allow-net --allow-env --allow-read --unstable --allow-write index.ts
INDEXER_PID=$!

# Start the API server

echo "Starting API server..."
deno run --allow-net --allow-env --allow-read api.ts &
API_PID=$!

# Handle termination

trap "kill $INDEXER_PID $API_PID; exit" SIGINT SIGTERM

# Wait for both processes

wait $INDEXER_PID $API_PID

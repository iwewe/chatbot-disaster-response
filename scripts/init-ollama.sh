#!/bin/bash

# Initialize Ollama with required model
# This script should be run after docker-compose up

set -e

echo "🤖 Initializing Ollama..."
echo "⏳ This may take several minutes for first-time download..."

# Wait for Ollama to be ready
echo "Waiting for Ollama service to be ready..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
  if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "✅ Ollama is ready!"
    break
  fi
  attempt=$((attempt + 1))
  echo "Attempt $attempt/$max_attempts..."
  sleep 5
done

if [ $attempt -eq $max_attempts ]; then
  echo "❌ Ollama failed to start. Please check logs:"
  echo "   docker logs emergency_ollama"
  exit 1
fi

# Pull the model (default: qwen2.5:7b)
MODEL_NAME=${OLLAMA_MODEL:-qwen2.5:7b}

echo "📥 Pulling model: $MODEL_NAME"
echo "   This will download ~4-5GB. Please be patient..."

docker exec -it emergency_ollama ollama pull $MODEL_NAME

if [ $? -eq 0 ]; then
  echo "✅ Model $MODEL_NAME downloaded successfully!"
  echo ""
  echo "Testing model..."
  docker exec -it emergency_ollama ollama run $MODEL_NAME "Test: Halo" --verbose false

  if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Model is working correctly!"
    echo "🎉 Ollama setup complete!"
  else
    echo "⚠️  Model test failed. Please check:"
    echo "   docker exec -it emergency_ollama ollama list"
  fi
else
  echo "❌ Failed to download model. Please check:"
  echo "   - Internet connection"
  echo "   - Disk space (need ~5-10GB free)"
  echo "   - Docker logs: docker logs emergency_ollama"
  exit 1
fi

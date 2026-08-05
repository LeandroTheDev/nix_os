#!/bin/bash
IMAGE_NAME="fex"
CONTAINER_NAME="fex"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$(docker images -q "$IMAGE_NAME" 2>/dev/null)" ]; then
  echo "Image not found, building..."
  docker build -t "$IMAGE_NAME" "$SCRIPT_DIR" || { echo "Build failed, aborting."; exit 1; }
fi

if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
  echo "Container already up, entering..."
  docker exec -it $CONTAINER_NAME bash
elif docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
  echo "Container stopped, starting..."
  docker start -ai $CONTAINER_NAME
else
  echo "Creating container..."
  mkdir -p "$HOME/app"
  docker run -it \
    --pull=never \
    --name fex \
    -v "$HOME/app:/home/admin/app" \
    fex bash
fi

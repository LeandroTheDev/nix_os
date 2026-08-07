#!/bin/bash
IMAGE_NAME="projectzomboidarm"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$(docker images -q "$IMAGE_NAME" 2>/dev/null)" ]; then
  echo "Image not found, building..."
  docker build -t "$IMAGE_NAME" "$SCRIPT_DIR" || { echo "Build failed, aborting."; exit 1; }
fi

read -p "Enter the name for the container: " CONTAINER_NAME
while [ -z "$CONTAINER_NAME" ]; do
  read -p "Container name cannot be empty, please enter a name: " CONTAINER_NAME
done

if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
  echo "Container already up, attaching to logs (Ctrl+C to detach, container keeps running)..."
  sleep 2
  docker logs -f "$CONTAINER_NAME"
  echo "To enter the container, run:"
  echo "  docker exec -it $CONTAINER_NAME bash"
  exit 0
elif docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
  echo "Container stopped, starting..."
  docker start -ai "$CONTAINER_NAME"
  exit 0
fi

read -p "Enter the path to your Zomboid data folder on this device: " ZOMBOID_PATH
MOUNTS=(-v "${ZOMBOID_PATH}:/home/admin/Zomboid")

read -p "Do you need to mount anything else? (y/n): " NEED_MORE_MOUNTS
while [[ "$NEED_MORE_MOUNTS" =~ ^[Yy]$ ]]; do
  read -p "  Path on your device: " HOST_PATH
  read -p "  Path inside the container (relative to /home/admin/): " CONTAINER_SUBPATH
  MOUNTS+=(-v "${HOST_PATH}:/home/admin/${CONTAINER_SUBPATH}")
  read -p "Do you need to mount anything else? (y/n): " NEED_MORE_MOUNTS
done

read -p "How much RAM should the server use, in GB [2]: " PZ_MEMORY_GB
PZ_MEMORY_GB="${PZ_MEMORY_GB:-2}"

echo "Creating container..."
docker run -dit \
  --pull=never \
  --network host \
  --name "$CONTAINER_NAME" \
  -e PZ_MEMORY="${PZ_MEMORY_GB}g" \
  "${MOUNTS[@]}" \
  "$IMAGE_NAME"

if [ $? -eq 0 ]; then
  echo "Container '$CONTAINER_NAME' created successfully."
  echo "Attaching to logs (Ctrl+C to detach, container keeps running in background)..."
  sleep 2
  docker logs -f "$CONTAINER_NAME"
  echo "To enter the container, run:"
  echo "  docker exec -it $CONTAINER_NAME bash"
else
  echo "Failed to create container."
  exit 1
fi

#!/usr/bin/env bash
IMAGE_NAME="left4dead2dedicatedserverarm"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$(docker images -q "$IMAGE_NAME" 2>/dev/null)" ]; then
  echo "Image not found, building..."
  docker build -t "$IMAGE_NAME" "$SCRIPT_DIR" || { echo "Build failed, aborting."; exit 1; }
else
  read -p "Image '$IMAGE_NAME' already exists. Rebuild it? (y/N): " REBUILD_IMAGE
  if [[ "$REBUILD_IMAGE" =~ ^[Yy]$ ]]; then
    echo "Rebuilding image..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR" || { echo "Build failed, aborting."; exit 1; }
  fi
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
  echo "To attach to the server console (tmux), run:"
  echo "  docker exec -it $CONTAINER_NAME tmux attach -t l4d2"
  echo "  (Ctrl+B then D to detach without stopping the server)"
  exit 0
elif docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
  echo "Container stopped, starting..."
  docker start -ai "$CONTAINER_NAME"
  exit 0
fi

read -p "Enter the path to your server data folder on this device: " DATA_PATH
MOUNTS=(-v "${DATA_PATH}:/home/admin/app")

read -p "Do you need to mount anything else? (y/N): " NEED_MORE_MOUNTS
while [[ "$NEED_MORE_MOUNTS" =~ ^[Yy]$ ]]; do
  read -p "  Path on your device: " HOST_PATH
  read -p "  Path inside the container (relative to /home/admin/): " CONTAINER_SUBPATH
  MOUNTS+=(-v "${HOST_PATH}:/home/admin/${CONTAINER_SUBPATH}")
  read -p "Do you need to mount anything else? (y/N): " NEED_MORE_MOUNTS
done

read -p "Server port [27015]: " L4D2_PORT
L4D2_PORT="${L4D2_PORT:-27015}"

read -p "Max players [4]: " L4D2_MAXPLAYERS
L4D2_MAXPLAYERS="${L4D2_MAXPLAYERS:-4}"

read -p "Starting map [c1m1_hotel]: " L4D2_MAP
L4D2_MAP="${L4D2_MAP:-c1m1_hotel}"

echo "Creating container..."
docker run -dit \
  --pull=never \
  --network host \
  --name "$CONTAINER_NAME" \
  -e L4D2_PORT="$L4D2_PORT" \
  -e L4D2_MAXPLAYERS="$L4D2_MAXPLAYERS" \
  -e L4D2_MAP="$L4D2_MAP" \
  "${MOUNTS[@]}" \
  "$IMAGE_NAME"

if [ $? -eq 0 ]; then
  echo "Container '$CONTAINER_NAME' created successfully."
  echo "Attaching to logs (Ctrl+C to detach, container keeps running in background)..."
  sleep 2
  docker logs -f "$CONTAINER_NAME"
  echo "To enter the container, run:"
  echo "  docker exec -it $CONTAINER_NAME bash"
  echo "To attach to the server console (tmux), run:"
  echo "  docker exec -it $CONTAINER_NAME tmux attach -t l4d2"
  echo "  (Ctrl+B then D to detach without stopping the server)"
else
  echo "Failed to create container."
  exit 1
fi

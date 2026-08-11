#!/usr/bin/env bash
IMAGE_NAME="left4dead2dedicatedserverarm"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
L4D2_VOLUME="l4d2-data"
STEAMCMD_VOLUME="steamcmd-data"
L4D2_INSTALL_PATH="/home/admin/app/l4d2server"
STEAMCMD_PATH="/home/admin/app/steamcmd"

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

# ── Install/update L4D2 via SteamCMD (runs the image in init mode) ─────────────
if docker run --rm --entrypoint test -v "${L4D2_VOLUME}:${L4D2_INSTALL_PATH}" \
    "$IMAGE_NAME" -f "${L4D2_INSTALL_PATH}/.ready" 2>/dev/null; then
  read -p "L4D2 is already installed. Update it now? (y/N): " DO_INIT
else
  echo "L4D2 is not installed yet, installation is required."
  DO_INIT="y"
fi

if [[ "$DO_INIT" =~ ^[Yy]$ ]]; then
  read -p "Steam username (must own L4D2): " STEAM_USERNAME
  while [ -z "$STEAM_USERNAME" ]; do
    read -p "Username cannot be empty, please enter your Steam username: " STEAM_USERNAME
  done

  echo "Installing/updating L4D2, this may take a while..."
  echo "Valve requires an authenticated Steam login — type the password and Steam"
  echo "Guard code (if asked) directly into the prompt below."
  docker run -it --rm \
    -e L4D2_MODE=init \
    -e STEAM_USERNAME="$STEAM_USERNAME" \
    -v "${L4D2_VOLUME}:${L4D2_INSTALL_PATH}" \
    -v "${STEAMCMD_VOLUME}:${STEAMCMD_PATH}" \
    "$IMAGE_NAME"

  if [ $? -ne 0 ]; then
    echo "L4D2 installation failed, aborting."
    exit 1
  fi
fi

MOUNTS=(-v "${L4D2_VOLUME}:${L4D2_INSTALL_PATH}")

read -p "Do you need to mount anything else? (y/N): " NEED_MORE_MOUNTS
while [[ "$NEED_MORE_MOUNTS" =~ ^[Yy]$ ]]; do
  read -p "  Path on your device: " HOST_PATH
  read -p "  Path inside the container (relative to /home/admin/): " CONTAINER_SUBPATH
  MOUNTS+=(-v "${HOST_PATH}:/home/admin/${CONTAINER_SUBPATH}")
  read -p "Do you need to mount anything else? (y/N): " NEED_MORE_MOUNTS
done

read -p "Server port [27015]: " L4D2_PORT
L4D2_PORT="${L4D2_PORT:-27015}"

read -p "Max players [8]: " L4D2_MAXPLAYERS
L4D2_MAXPLAYERS="${L4D2_MAXPLAYERS:-8}"

read -p "Starting map [c1m1_hotel]: " L4D2_MAP
L4D2_MAP="${L4D2_MAP:-c1m1_hotel}"

read -p "Game types (sv_gametypes, optional): " L4D2_GAMETYPES
read -p "Game mode (mp_gamemode, optional): " L4D2_GAMEMODE
read -p "Extra srcds_linux arguments (optional): " L4D2_ARGS

echo "Creating container..."
docker run -dit \
  --pull=never \
  --network host \
  --name "$CONTAINER_NAME" \
  -e L4D2_PORT="$L4D2_PORT" \
  -e L4D2_MAXPLAYERS="$L4D2_MAXPLAYERS" \
  -e L4D2_MAP="$L4D2_MAP" \
  -e L4D2_GAMETYPES="$L4D2_GAMETYPES" \
  -e L4D2_GAMEMODE="$L4D2_GAMEMODE" \
  -e L4D2_ARGS="$L4D2_ARGS" \
  "${MOUNTS[@]}" \
  "$IMAGE_NAME"

if [ $? -eq 0 ]; then
  echo "Container '$CONTAINER_NAME' created successfully."
  sleep 2
  echo "Following logs (Ctrl+C to detach, container keeps running)..."
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

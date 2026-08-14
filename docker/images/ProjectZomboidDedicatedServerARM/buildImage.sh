#!/usr/bin/env bash
IMAGE_NAME="projectzomboiddedicatedserverarm"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

read -p "Docker compose file path [$DEFAULT_COMPOSE_FILE]: " COMPOSE_FILE
COMPOSE_FILE="${COMPOSE_FILE:-$DEFAULT_COMPOSE_FILE}"
while [ ! -f "$COMPOSE_FILE" ]; do
  read -p "File not found at '$COMPOSE_FILE'. Enter a valid docker-compose file path: " COMPOSE_FILE
done

dc() {
  docker compose -f "$COMPOSE_FILE" --project-directory "$SCRIPT_DIR" "$@"
}

# ── Zomboid data folder — external, kept outside the container so it survives
# rebuilds/recreations. Exported (not just passed to one call) so every `dc`
# invocation below — build included, since `docker compose build` still
# interpolates the whole file, volumes section and all — resolves the same
# path instead of failing on an unset variable.
DEFAULT_ZOMBOID_PATH="$HOME/Zomboid"
read -p "Zomboid data folder path on this host [$DEFAULT_ZOMBOID_PATH]: " ZOMBOID_DATA_PATH
export ZOMBOID_DATA_PATH="${ZOMBOID_DATA_PATH:-$DEFAULT_ZOMBOID_PATH}"

mkdir -p "$ZOMBOID_DATA_PATH"
sudo chown -R 1000:1000 "$ZOMBOID_DATA_PATH"

read -p "RAM for the server, e.g. 2g/4g [2g]: " PZ_MEMORY
export PZ_MEMORY="${PZ_MEMORY:-2g}"

if [ -z "$(docker images -q "$IMAGE_NAME" 2>/dev/null)" ]; then
  echo "Image not found, building..."
  dc build || { echo "Build failed, aborting."; exit 1; }
else
  read -p "Image '$IMAGE_NAME' already exists. Rebuild it? (y/N): " REBUILD_IMAGE
  if [[ "$REBUILD_IMAGE" =~ ^[Yy]$ ]]; then
    echo "Rebuilding image..."
    dc build || { echo "Build failed, aborting."; exit 1; }
  fi
fi

echo "Build complete. This script does not start the server automatically."
echo "To start it (this also installs/updates PZ via SteamCMD on first run), run:"
echo "  ZOMBOID_DATA_PATH=\"$ZOMBOID_DATA_PATH\" PZ_MEMORY=\"$PZ_MEMORY\" docker compose -f \"$COMPOSE_FILE\" --project-directory \"$SCRIPT_DIR\" up -d"
echo "Then attach to the server console with:"
echo "  docker exec -it <container> tmux attach -t zomboid"
echo "  (Ctrl+B then D to detach without stopping the server)"

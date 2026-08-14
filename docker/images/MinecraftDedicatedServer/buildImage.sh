#!/usr/bin/env bash
IMAGE_NAME="minecraftdedicatedserver"
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

# ── Download/update Paper via the PaperMC API ────────────────────────────────
DEFAULT_INIT_SERVICE="minecraft-init"
read -p "Init service name [$DEFAULT_INIT_SERVICE]: " INIT_SERVICE
INIT_SERVICE="${INIT_SERVICE:-$DEFAULT_INIT_SERVICE}"

echo "Downloading Minecraft (Paper) server, this may take a while..."
dc run --rm "$INIT_SERVICE" || { echo "Paper download failed, aborting."; exit 1; }

# ── Start the server ──────────────────────────────────────────────────────────
echo "Starting server..."
dc up -d || { echo "Failed to start server."; exit 1; }

dc ps
echo "Attach to server console: docker exec -it minecraft tmux attach -t mc"
echo "  (Ctrl+B then D to detach without stopping the server)"

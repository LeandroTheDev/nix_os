#!/usr/bin/env bash
IMAGE_NAME="nomoreroominhelldedicatedserverarm"
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

# ── Install/update NMRiH via SteamCMD ───────────────────────────────────────
# NMRiH is free-to-play, so this uses an anonymous SteamCMD login — no Steam
# account or password is needed here.
DEFAULT_INIT_SERVICE="nmrih-init"
read -p "SteamCMD init service name [$DEFAULT_INIT_SERVICE]: " INIT_SERVICE
INIT_SERVICE="${INIT_SERVICE:-$DEFAULT_INIT_SERVICE}"

echo "Installing/updating NMRiH, this may take a while..."
dc run --rm "$INIT_SERVICE" || { echo "NMRiH installation failed, aborting."; exit 1; }

# ── Start the game servers defined in the compose file ──────────────────────
echo "Starting servers..."
dc up -d || { echo "Failed to start servers."; exit 1; }

dc ps
echo "Attach to a server console: docker exec -it <container> tmux attach -t nmrih"
echo "  (Ctrl+B then D to detach without stopping the server)"

#!/usr/bin/env bash
IMAGE_NAME="left4dead2dedicatedserverarm"
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

# ── Install/update L4D2 via SteamCMD ────────────────────────────────────────
DEFAULT_INIT_SERVICE="l4d2-init"
read -p "SteamCMD init service name [$DEFAULT_INIT_SERVICE]: " INIT_SERVICE
INIT_SERVICE="${INIT_SERVICE:-$DEFAULT_INIT_SERVICE}"

read -p "Steam username (must own L4D2): " STEAM_USERNAME
while [ -z "$STEAM_USERNAME" ]; do
  read -p "Username cannot be empty, please enter your Steam username: " STEAM_USERNAME
done

# Valve requires an authenticated Steam login to download the L4D2 dedicated
# server depot, and the password/Steam Guard code prompts need a real
# interactive terminal — so this script never runs the init or the servers
# for you. Run the commands below yourself.
echo ""
echo "This script does not download or start anything automatically."
echo "L4D2 requires an authenticated Steam login, so run the init container yourself:"
echo "  STEAM_USERNAME=$STEAM_USERNAME docker compose -f \"$COMPOSE_FILE\" --project-directory \"$SCRIPT_DIR\" run --rm $INIT_SERVICE"
echo "Type your Steam password and Guard code (if asked) directly into that prompt."
echo ""
echo "Once it finishes successfully, start the game servers with:"
echo "  docker compose -f \"$COMPOSE_FILE\" --project-directory \"$SCRIPT_DIR\" up -d"
echo "Then attach to a server console with:"
echo "  docker exec -it <container> tmux attach -t l4d2"
echo "  (Ctrl+B then D to detach without stopping the server)"

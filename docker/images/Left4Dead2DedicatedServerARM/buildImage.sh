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

# STEAM_USERNAME is exported (not just passed with -e to this one call) so
# that if `docker compose up` below needs to run the init service itself to
# satisfy depends_on (e.g. because this run's container already exited and
# got removed), it still resolves ${STEAM_USERNAME} correctly from the
# compose file instead of defaulting to blank and failing.
read -p "Steam username (must own L4D2): " STEAM_USERNAME
while [ -z "$STEAM_USERNAME" ]; do
  read -p "Username cannot be empty, please enter your Steam username: " STEAM_USERNAME
done
export STEAM_USERNAME

echo "Installing/updating L4D2, this may take a while..."
echo "Valve requires an authenticated Steam login — type the password and Steam"
echo "Guard code (if asked) directly into the prompt below."
dc run --rm "$INIT_SERVICE" || { echo "L4D2 installation failed, aborting."; exit 1; }

# ── Start the game servers defined in the compose file ──────────────────────
echo "Starting servers..."
dc up -d || { echo "Failed to start servers."; exit 1; }

dc ps
echo "Attach to a server console: docker exec -it <container> tmux attach -t l4d2"
echo "  (Ctrl+B then D to detach without stopping the server)"

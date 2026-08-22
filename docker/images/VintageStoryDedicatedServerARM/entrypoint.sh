#!/usr/bin/env bash
# VS_MODE=init          — downloads/updates the server via vs_updater and exits.
# VS_MODE=server        — waits for installation and starts the server (default).
# VS_SKIP_MOD_UPDATE=1  — skips mod update step on server startup.
set -uo pipefail

APP_PATH="${APP_PATH:-/home/admin/app}"
VS_INSTALL_DIR="$APP_PATH/vs"
READY_MARKER="$VS_INSTALL_DIR/.ready"
TMUX_SESSION="vintagestory"

# ── init ─────────────────────────────────────────────────────────────────────
if [ "${VS_MODE:-server}" = "init" ]; then
    mkdir -p "$VS_INSTALL_DIR"

    echo "==> Running vs_updater to install/update Vintage Story server..."
    vintagestory_updater \
        --working-path "$VS_INSTALL_DIR" \
        --game-type server \
        --arch arm64 \
        --no-pre || { echo "ERROR: updater failed"; exit 1; }

    if [ ! -f "$VS_INSTALL_DIR/VintagestoryServer.dll" ]; then
        echo "ERROR: VintagestoryServer.dll not found after update." >&2
        exit 1
    fi

    touch "$READY_MARKER"
    echo "==> Installation complete."
    exit 0
fi

# ── server ───────────────────────────────────────────────────────────────────
echo "==> Waiting for VS installation at $VS_INSTALL_DIR..."
until [ -f "$READY_MARKER" ]; do
    sleep 5
done
echo "==> Installation ready."

if [ "${VS_SKIP_MOD_UPDATE:-0}" != "1" ]; then
    echo "==> Updating mods..."
    vintagestory_updater \
        --working-path "$VS_INSTALL_DIR" \
        --mods-path /serverdata/Mods \
        --ignore-game-update || { echo "ERROR: mod update failed"; exit 1; }
fi

cp /opt/start-server.sh "$VS_INSTALL_DIR/start-server.sh"
chmod +x "$VS_INSTALL_DIR/start-server.sh"

echo "==> Starting Vintage Story server on port ${VS_PORT:-42420} in tmux session '$TMUX_SESSION'..."
tmux new-session -d -s "$TMUX_SESSION" -c "$VS_INSTALL_DIR" "$VS_INSTALL_DIR/start-server.sh"

SHUTDOWN_TIMEOUT="${VS_SHUTDOWN_TIMEOUT:-30}"

shutdown_server() {
    echo "==> Shutdown requested, sending SIGTERM to server..."
    DOTNET_PID=$(pgrep -f VintagestoryServer.dll 2>/dev/null)
    [ -n "$DOTNET_PID" ] && kill -TERM "$DOTNET_PID" 2>/dev/null
    ELAPSED=0
    while tmux has-session -t "$TMUX_SESSION" 2>/dev/null && [ "$ELAPSED" -lt "$SHUTDOWN_TIMEOUT" ]; do
        sleep 2
        ELAPSED=$((ELAPSED + 2))
    done
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        echo "==> Server did not stop within ${SHUTDOWN_TIMEOUT}s, force-killing..."
        tmux kill-session -t "$TMUX_SESSION" 2>/dev/null
    fi
    exit 0
}

trap shutdown_server SIGTERM SIGINT

# Attach to server console: docker exec -it vs-server tmux attach -t vintagestory
while tmux has-session -t "$TMUX_SESSION" 2>/dev/null; do
    sleep 5 & wait $!
done

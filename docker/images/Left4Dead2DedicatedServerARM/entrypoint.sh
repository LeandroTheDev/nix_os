#!/usr/bin/env bash
# L4D2_MODE=init    — downloads/updates the server via SteamCMD and exits.
# L4D2_MODE=server  — waits for installation and starts the server (default).
set -uo pipefail

APP_PATH="${APP_PATH:-/home/admin/app}"
STEAMCMD_DIR="$APP_PATH/steamcmd"
L4D2_INSTALL_DIR="$APP_PATH/l4d2server"
L4D2_APPID=222860
READY_MARKER="$L4D2_INSTALL_DIR/.ready"
TMUX_SESSION="l4d2"

# ── init ─────────────────────────────────────────────────────────────────────
if [ "${L4D2_MODE:-server}" = "init" ]; then
    if [ -z "${STEAM_USERNAME:-}" ]; then
        echo "ERROR: STEAM_USERNAME is not set." >&2
        exit 1
    fi

    mkdir -p "$STEAMCMD_DIR" "$L4D2_INSTALL_DIR"

    if [ ! -f "$STEAMCMD_DIR/linux32/steamcmd" ]; then
        echo "==> Downloading SteamCMD..."
        (cd "$STEAMCMD_DIR" && curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -)
    fi

    MAX_ATTEMPTS=10
    ATTEMPT=1
    SUCCESS=0
    while [ "$ATTEMPT" -le "$MAX_ATTEMPTS" ]; do
        echo "==> Running SteamCMD (attempt $ATTEMPT/$MAX_ATTEMPTS)..."
        (cd "$STEAMCMD_DIR" && LD_LIBRARY_PATH="linux32" FEX linux32/steamcmd \
            +force_install_dir "$L4D2_INSTALL_DIR" \
            +login "$STEAM_USERNAME" \
            +app_update "$L4D2_APPID" validate \
            +quit)

        if [ -f "$L4D2_INSTALL_DIR/srcds_linux" ]; then
            SUCCESS=1
            break
        fi
        echo "==> srcds_linux not found, retrying..."
        ATTEMPT=$((ATTEMPT + 1))
        sleep 2
    done

    if [ "$SUCCESS" -ne 1 ]; then
        echo "ERROR: SteamCMD failed after $MAX_ATTEMPTS attempts." >&2
        exit 1
    fi

    touch "$READY_MARKER"
    echo "==> Installation complete."
    exit 0
fi

# ── server ───────────────────────────────────────────────────────────────────
echo "==> Waiting for L4D2 installation at $L4D2_INSTALL_DIR..."
until [ -f "$READY_MARKER" ]; do
    sleep 5
done
echo "==> Installation ready."

mkdir -p "$HOME/.steam/sdk32"
ln -sf "$L4D2_INSTALL_DIR/bin/steamclient.so" "$HOME/.steam/sdk32/steamclient.so"

cp /opt/start-server.sh "$L4D2_INSTALL_DIR/start-server.sh"
chmod +x "$L4D2_INSTALL_DIR/start-server.sh"

STARTUP_LOG="/tmp/l4d2-startup.log"
STARTUP_TIMEOUT="${L4D2_STARTUP_TIMEOUT:-120}"

echo "==> Starting server (${L4D2_GAMEMODE:-?}) on port ${L4D2_PORT:-27015} in tmux session '$TMUX_SESSION'..."
> "$STARTUP_LOG"
tmux new-session -d -s "$TMUX_SESSION" -c "$L4D2_INSTALL_DIR" "$L4D2_INSTALL_DIR/start-server.sh"
tmux pipe-pane -t "$TMUX_SESSION" -o "cat >> $STARTUP_LOG"

(
    ELAPSED=0
    while [ "$ELAPSED" -lt "$STARTUP_TIMEOUT" ]; do
        if grep -qE "Connection to Steam servers successful|VAC secure mode is activated|Server is hibernating" "$STARTUP_LOG" 2>/dev/null; then
            echo "==> Watchdog: server started after ${ELAPSED}s."
            tmux pipe-pane -t "$TMUX_SESSION" 2>/dev/null
            exit 0
        fi
        sleep 10
        ELAPSED=$((ELAPSED + 10))
    done
    echo "==> Watchdog: server did not start within ${STARTUP_TIMEOUT}s — killing session to trigger restart..."
    tmux kill-session -t "$TMUX_SESSION"
) &

SHUTDOWN_TIMEOUT="${L4D2_SHUTDOWN_TIMEOUT:-30}"

shutdown_server() {
    echo "==> Shutdown requested, sending 'quit' to server console..."
    tmux send-keys -t "$TMUX_SESSION" "" Enter
    sleep 1
    tmux send-keys -t "$TMUX_SESSION" "quit" Enter
    ELAPSED=0
    while tmux has-session -t "$TMUX_SESSION" 2>/dev/null && [ "$ELAPSED" -lt "$SHUTDOWN_TIMEOUT" ]; do
        sleep 2
        ELAPSED=$((ELAPSED + 2))
    done
    tmux kill-session -t "$TMUX_SESSION" 2>/dev/null
    exit 0
}

trap shutdown_server SIGTERM SIGINT

# Attach to server console: docker exec -it <container> tmux attach -t l4d2
while tmux has-session -t "$TMUX_SESSION" 2>/dev/null; do
    sleep 5 & wait $!
done

#!/usr/bin/env bash
# NMRIH_MODE=init    — downloads/updates the server via SteamCMD (anonymous login) and exits.
# NMRIH_MODE=server  — waits for installation and starts the server (default).
set -uo pipefail

APP_PATH="${APP_PATH:-/home/admin/app}"
STEAMCMD_DIR="$APP_PATH/steamcmd"
NMRIH_INSTALL_DIR="$APP_PATH/nmrihserver"
NMRIH_APPID=317670
READY_MARKER="$NMRIH_INSTALL_DIR/.ready"
TMUX_SESSION="nmrih"

# ── init ─────────────────────────────────────────────────────────────────────
# NMRiH is free-to-play, so its dedicated server can be downloaded with an
# anonymous SteamCMD login — no Steam account/credentials required.
if [ "${NMRIH_MODE:-server}" = "init" ]; then
    mkdir -p "$STEAMCMD_DIR" "$NMRIH_INSTALL_DIR"

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
            +force_install_dir "$NMRIH_INSTALL_DIR" \
            +login anonymous \
            +app_update "$NMRIH_APPID" \
            +quit)

        if [ -f "$NMRIH_INSTALL_DIR/srcds_linux" ]; then
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
echo "==> Waiting for NMRiH installation at $NMRIH_INSTALL_DIR..."
until [ -f "$READY_MARKER" ]; do
    sleep 5
done
echo "==> Installation ready."

mkdir -p "$HOME/.steam/sdk32"
ln -sf "$NMRIH_INSTALL_DIR/bin/steamclient.so" "$HOME/.steam/sdk32/steamclient.so"

cp /opt/start-server.sh "$NMRIH_INSTALL_DIR/start-server.sh"
chmod +x "$NMRIH_INSTALL_DIR/start-server.sh"

STARTUP_LOG="/tmp/nmrih-startup.log"
STARTUP_TIMEOUT="${NMRIH_STARTUP_TIMEOUT:-120}"

echo "==> Starting server on port ${NMRIH_PORT:-27015} in tmux session '$TMUX_SESSION'..."
> "$STARTUP_LOG"
tmux new-session -d -s "$TMUX_SESSION" -c "$NMRIH_INSTALL_DIR" "$NMRIH_INSTALL_DIR/start-server.sh"
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

SHUTDOWN_TIMEOUT="${NMRIH_SHUTDOWN_TIMEOUT:-30}"

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

# Attach to server console: docker exec -it <container> tmux attach -t nmrih
while tmux has-session -t "$TMUX_SESSION" 2>/dev/null; do
    sleep 5 & wait $!
done

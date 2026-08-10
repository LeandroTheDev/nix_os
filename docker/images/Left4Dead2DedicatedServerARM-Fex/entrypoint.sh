#!/usr/bin/env bash
set -uo pipefail

APP_PATH="${APP_PATH:-/home/admin/app}"
STEAMCMD_DIR="$APP_PATH/steamcmd"
L4D2_INSTALL_DIR="$APP_PATH/l4d2server"
L4D2_APPID=222860
TMUX_SESSION="l4d2"

if [ -z "${STEAM_USERNAME:-}" ]; then
    echo "ERROR: STEAM_USERNAME is not set. Valve now requires an authenticated" >&2
    echo "Steam login to download the L4D2 dedicated server depot (222860) —" >&2
    echo "anonymous login fails with 'Invalid platform'. Set -e STEAM_USERNAME=<user>" >&2
    echo "when creating the container and attach to enter the password/Steam Guard" >&2
    echo "code interactively on first login." >&2
    exit 1
fi

mkdir -p "$STEAMCMD_DIR" "$L4D2_INSTALL_DIR"

# 1. Download SteamCMD once, persisted in the container's own filesystem
if [ ! -f "$STEAMCMD_DIR/linux32/steamcmd" ]; then
    echo "==> Downloading SteamCMD..."
    (cd "$STEAMCMD_DIR" && curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -)
fi

# 2. Run SteamCMD through FEX (32-bit x86) to install/update the L4D2 dedicated
# server. FEX runs it against the RootFS baked into the image at build time.
# Retry a few times — SteamCMD can report success even after failing.
# Success is judged by presence of srcds_linux, not by exit code.

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
    echo "==> SteamCMD did not install the server, retrying..."
    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
done

if [ "$SUCCESS" -ne 1 ]; then
    echo "ERROR: SteamCMD failed after $MAX_ATTEMPTS attempts, aborting." >&2
    exit 1
fi

echo "==> Left 4 Dead 2 server ready at $L4D2_INSTALL_DIR"

# srcds looks for steamclient.so under ~/.steam/sdk32 to talk to Steam/VAC
mkdir -p "$HOME/.steam/sdk32"
ln -sf "$L4D2_INSTALL_DIR/bin/steamclient.so" "$HOME/.steam/sdk32/steamclient.so"

# Drop the FEX launcher next to srcds_linux
cp /opt/start-server-fex.sh "$L4D2_INSTALL_DIR/start-server-fex.sh"
chmod +x "$L4D2_INSTALL_DIR/start-server-fex.sh"

STARTUP_LOG="/tmp/l4d2-startup.log"
STARTUP_TIMEOUT="${L4D2_STARTUP_TIMEOUT:-120}"

echo "==> Starting Left 4 Dead 2 server in tmux session '$TMUX_SESSION'..."
> "$STARTUP_LOG"
tmux new-session -d -s "$TMUX_SESSION" -c "$L4D2_INSTALL_DIR" "$L4D2_INSTALL_DIR/start-server-fex.sh"
tmux pipe-pane -t "$TMUX_SESSION" -o "cat >> $STARTUP_LOG"

# Watchdog: if the startup marker doesn't appear within STARTUP_TIMEOUT seconds
# the server is considered stuck and the session is killed so Docker restarts.
(
    ELAPSED=0
    while [ "$ELAPSED" -lt "$STARTUP_TIMEOUT" ]; do
        if grep -qE "Connection to Steam servers successful|VAC secure mode is activated|Server is hibernating" "$STARTUP_LOG" 2>/dev/null; then
            echo "==> Watchdog: server startup confirmed after ${ELAPSED}s."
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

# Keep the container alive while the tmux session (the server) is running.
# Attach to the server console with:
#   docker exec -it <container> tmux attach -t l4d2
while tmux has-session -t "$TMUX_SESSION" 2>/dev/null; do
    sleep 5 & wait $!
done

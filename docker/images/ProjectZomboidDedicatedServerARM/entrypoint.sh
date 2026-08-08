#!/usr/bin/env bash
set -uo pipefail

APP_PATH="${APP_PATH:-/home/admin/app}"
STEAMCMD_DIR="$APP_PATH/steamcmd"
PZ_INSTALL_DIR="$APP_PATH/pzserver"
PZ_APPID=380870
TMUX_SESSION="zomboid"

mkdir -p "$STEAMCMD_DIR" "$PZ_INSTALL_DIR"

# 1. Download SteamCMD once, persisted in the mounted volume
if [ ! -f "$STEAMCMD_DIR/linux32/steamcmd" ]; then
    echo "==> Downloading SteamCMD..."
    (cd "$STEAMCMD_DIR" && curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -)
fi

# 2. Run SteamCMD through box86 to install/update the Project Zomboid
# dedicated server. steamcmd.sh is just a shell wrapper (box86 can only
# execute ELF binaries), so run the linux32/steamcmd binary directly, from
# inside the steamcmd dir, with BOX86_LD_LIBRARY_PATH pointed at linux32/ for
# the Steam client libs - same as what steamcmd.sh itself would set up.
# box86 runs SteamCMD (x86 32bit) natively as an ARM 32bit process, which is
# more reliable for SteamCMD than box64's 32bit compat mode - none of the
# box64-specific quirk workarounds are needed here.
# SteamCMD (and the game update itself) can still flake out, so retry a few
# times before giving up. Note: SteamCMD's own exit code is not trustworthy
# here - it can report success even after printing
# "ERROR! Failed to install app ... (Missing configuration)" and installing
# nothing. So success is judged by the presence of the game's own
# start-server.sh afterwards, not by the command's exit status.

MAX_ATTEMPTS=10
ATTEMPT=1
SUCCESS=0
while [ "$ATTEMPT" -le "$MAX_ATTEMPTS" ]; do
    echo "==> Running SteamCMD (attempt $ATTEMPT/$MAX_ATTEMPTS)..."
    (cd "$STEAMCMD_DIR" && BOX86_LD_LIBRARY_PATH="linux32" box86 linux32/steamcmd \
        +force_install_dir "$PZ_INSTALL_DIR" \
        +login anonymous \
        +app_update "$PZ_APPID" \
        +quit)

    if [ -f "$PZ_INSTALL_DIR/start-server.sh" ]; then
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

echo "==> Project Zomboid server ready at $PZ_INSTALL_DIR"

# Drop the box64 launcher next to the official start-server.sh
cp /opt/start-server-box64.sh "$PZ_INSTALL_DIR/start-server-box64.sh"
chmod +x "$PZ_INSTALL_DIR/start-server-box64.sh"

STARTUP_LOG="/tmp/pz-startup.log"
STARTUP_TIMEOUT="${PZ_STARTUP_TIMEOUT:-480}"

echo "==> Starting Project Zomboid server in tmux session '$TMUX_SESSION'..."
> "$STARTUP_LOG"
tmux new-session -d -s "$TMUX_SESSION" -c "$PZ_INSTALL_DIR" "$PZ_INSTALL_DIR/start-server-box64.sh"
# Capture server stdout so the watchdog can scan it without attaching to tmux
tmux pipe-pane -t "$TMUX_SESSION" -o "cat >> $STARTUP_LOG"

# Watchdog: if neither startup marker appears within STARTUP_TIMEOUT seconds
# the server is considered stuck. Kill the session so Docker restarts the
# container (requires restart: unless-stopped / on-failure in compose/run).
(
    ELAPSED=0
    while [ "$ELAPSED" -lt "$STARTUP_TIMEOUT" ]; do
        if grep -qE "Enter new administrator password|Initialising Server Systems" "$STARTUP_LOG" 2>/dev/null; then
            echo "==> Watchdog: server startup confirmed after ${ELAPSED}s."
            # Stop capturing tmux output — startup phase is over
            tmux pipe-pane -t "$TMUX_SESSION" 2>/dev/null
            exit 0
        fi
        sleep 10
        ELAPSED=$((ELAPSED + 10))
    done
    echo "==> Watchdog: server did not start within ${STARTUP_TIMEOUT}s — killing session to trigger restart..."
    tmux kill-session -t "$TMUX_SESSION"
) &

SHUTDOWN_CMD="${PZ_SHUTDOWN_CMD:-quit}"
SHUTDOWN_TIMEOUT="${PZ_SHUTDOWN_TIMEOUT:-60}"

shutdown_server() {
    echo "==> Shutdown requested, sending '$SHUTDOWN_CMD' to server console..."
    tmux send-keys -t "$TMUX_SESSION" "" Enter
    sleep 1
    tmux send-keys -t "$TMUX_SESSION" "$SHUTDOWN_CMD" Enter
    ELAPSED=0
    while tmux has-session -t "$TMUX_SESSION" 2>/dev/null && [ "$ELAPSED" -lt "$SHUTDOWN_TIMEOUT" ]; do
        sleep 2
        ELAPSED=$((ELAPSED + 2))
    done
    tmux kill-session -t "$TMUX_SESSION" 2>/dev/null
    exit 0
}

trap shutdown_server SIGTERM SIGINT

# Keep the container alive for as long as the tmux session (i.e. the server)
# is up, so admins can attach to the server console with:
#   docker exec -it <container> tmux attach -t zomboid
while tmux has-session -t "$TMUX_SESSION" 2>/dev/null; do
    sleep 5 & wait $!
done

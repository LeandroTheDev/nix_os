#!/bin/bash
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
        +app_update "$PZ_APPID" validate \
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

echo "==> Starting Project Zomboid server in tmux session '$TMUX_SESSION'..."
tmux new-session -d -s "$TMUX_SESSION" "$PZ_INSTALL_DIR/start-server-box64.sh"

# Keep the container alive for as long as the tmux session (i.e. the server)
# is up, so admins can attach to the server console with:
#   docker exec -it <container> tmux attach -t zomboid
while tmux has-session -t "$TMUX_SESSION" 2>/dev/null; do
    sleep 5
done

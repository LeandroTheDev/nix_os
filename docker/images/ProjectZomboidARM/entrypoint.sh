#!/bin/bash
set -uo pipefail

APP_PATH="${APP_PATH:-/home/admin/app}"
STEAMCMD_DIR="$APP_PATH/steamcmd"
PZ_INSTALL_DIR="$APP_PATH/pzserver"
PZ_APPID=380870

mkdir -p "$STEAMCMD_DIR" "$PZ_INSTALL_DIR"

# 1. Download SteamCMD once, persisted in the mounted volume
if [ ! -f "$STEAMCMD_DIR/linux32/steamcmd" ]; then
    echo "==> Downloading SteamCMD..."
    (cd "$STEAMCMD_DIR" && curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -)
fi

# 2. Run SteamCMD through box64 to install/update the Project Zomboid dedicated
# server. steamcmd.sh is just a shell wrapper (box64 can only execute ELF
# binaries), so run the linux32/steamcmd binary directly, from inside the
# steamcmd dir, with LD_LIBRARY_PATH pointed at linux32/ for the Steam client
# libs - same as what steamcmd.sh itself would set up.
# SteamCMD (and the game update itself) can flake out under box64, so retry a
# few times before giving up.

# Fix steam connections
export BOX64_AES=0

MAX_ATTEMPTS=5
ATTEMPT=1
SUCCESS=0
while [ "$ATTEMPT" -le "$MAX_ATTEMPTS" ]; do
    echo "==> Running SteamCMD (attempt $ATTEMPT/$MAX_ATTEMPTS)..."
    if (cd "$STEAMCMD_DIR" && LD_LIBRARY_PATH="linux32:${LD_LIBRARY_PATH:-}" box64 linux32/steamcmd \
        +force_install_dir "$PZ_INSTALL_DIR" \
        +login anonymous \
        +app_update "$PZ_APPID" validate \
        +quit); then
        SUCCESS=1
        break
    fi
    echo "==> SteamCMD failed, retrying..."
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

echo "==> Starting Project Zomboid server..."
exec "$PZ_INSTALL_DIR/start-server-box64.sh"

#!/usr/bin/env bash
# MINECRAFT_MODE=init   — resolves MINECRAFT_VERSION against the PaperMC API and downloads paper.jar
#                  (and, if MINECRAFT_GEYSER=true, the latest Geyser + Floodgate plugin builds), then exits.
# MINECRAFT_MODE=server — waits for installation, accepts the EULA and starts the server (default).
set -uo pipefail

APP_PATH="${APP_PATH:-/home/admin/app}"
PAPER_INSTALL_DIR="$APP_PATH/paper"
READY_MARKER="$PAPER_INSTALL_DIR/.ready"
TMUX_SESSION="minecraft"
PAPER_API="https://fill.papermc.io/v3/projects/paper"
PAPER_USER_AGENT="nix_os-minecraft-dedicated-server-arm/1.0"
GEYSER_SPIGOT_URL="https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot"
FLOODGATE_SPIGOT_URL="https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"

# ── init ─────────────────────────────────────────────────────────────────────
if [ "${MINECRAFT_MODE:-server}" = "init" ]; then
    mkdir -p "$PAPER_INSTALL_DIR"

    paper_curl() {
        curl -fsSL -H "User-Agent: $PAPER_USER_AGENT" "$@"
    }

    MINECRAFT_VERSION="${MINECRAFT_VERSION:-latest}"
    if [ "$MINECRAFT_VERSION" = "latest" ]; then
        echo "==> Resolving latest Minecraft version from PaperMC..."
        MINECRAFT_VERSION="$(paper_curl "$PAPER_API" | jq -r '[.versions | to_entries[0].value[] | select(test("-pre|-rc") | not)] | .[0]')"
        [ -n "$MINECRAFT_VERSION" ] && [ "$MINECRAFT_VERSION" != "null" ] || { echo "ERROR: could not resolve latest Minecraft version." >&2; exit 1; }
    fi
    echo "==> Using Minecraft version $MINECRAFT_VERSION"

    echo "==> Resolving latest stable Paper build for $MINECRAFT_VERSION..."
    BUILD="$(paper_curl "$PAPER_API/versions/$MINECRAFT_VERSION/builds" | jq -r 'map(select(.channel == "STABLE")) | .[0] | .id')"

    if [ -z "$BUILD" ] || [ "$BUILD" = "null" ]; then
        echo "==> No stable build for $MINECRAFT_VERSION, searching for latest version with a stable build..."
        VERSIONS="$(paper_curl "$PAPER_API" | jq -r '.versions | to_entries[] | .value[]' | sort -V -r)"
        for VERSION in $VERSIONS; do
            VERSION_BUILDS="$(paper_curl "$PAPER_API/versions/$VERSION/builds")"
            STABLE_ID="$(echo "$VERSION_BUILDS" | jq -r 'map(select(.channel == "STABLE")) | .[0] | .id')"
            if [ -n "$STABLE_ID" ] && [ "$STABLE_ID" != "null" ]; then
                MINECRAFT_VERSION="$VERSION"
                BUILD="$STABLE_ID"
                echo "==> Found stable build for version $VERSION (build $BUILD)"
                break
            fi
        done
    fi

    [ -n "$BUILD" ] && [ "$BUILD" != "null" ] || { echo "ERROR: could not resolve a stable Paper build for any version." >&2; exit 1; }
    echo "==> Using Minecraft $MINECRAFT_VERSION, Paper build $BUILD"

    BUILDS_RESPONSE="$(paper_curl "$PAPER_API/versions/$MINECRAFT_VERSION/builds")"
    DOWNLOAD_URL="$(echo "$BUILDS_RESPONSE" | jq -r 'map(select(.channel == "STABLE")) | .[0] | .downloads."server:default".url')"
    [ -n "$DOWNLOAD_URL" ] && [ "$DOWNLOAD_URL" != "null" ] || { echo "ERROR: could not resolve a download URL for $MINECRAFT_VERSION build $BUILD." >&2; exit 1; }

    echo "==> Downloading $DOWNLOAD_URL..."
    curl -fsSL "$DOWNLOAD_URL" -o "$PAPER_INSTALL_DIR/paper.jar" || { echo "ERROR: download failed"; exit 1; }

    if [ ! -s "$PAPER_INSTALL_DIR/paper.jar" ]; then
        echo "ERROR: paper.jar not found after download." >&2
        exit 1
    fi

    if [ "${MINECRAFT_GEYSER:-false}" = "true" ]; then
        mkdir -p /serverdata/plugins

        echo "==> Downloading latest Geyser (Spigot) build..."
        curl -fsSL "$GEYSER_SPIGOT_URL" -o /serverdata/plugins/Geyser-Spigot.jar || { echo "ERROR: Geyser download failed"; exit 1; }

        echo "==> Downloading latest Floodgate (Spigot) build..."
        curl -fsSL "$FLOODGATE_SPIGOT_URL" -o /serverdata/plugins/floodgate-spigot.jar || { echo "ERROR: Floodgate download failed"; exit 1; }

        [ -s /serverdata/plugins/Geyser-Spigot.jar ] && [ -s /serverdata/plugins/floodgate-spigot.jar ] || {
            echo "ERROR: Geyser/Floodgate jar missing after download." >&2
            exit 1
        }
    fi

    touch "$READY_MARKER"
    echo "==> Installation complete."
    exit 0
fi

# ── server ───────────────────────────────────────────────────────────────────
echo "==> Waiting for Paper installation at $PAPER_INSTALL_DIR..."
until [ -f "$READY_MARKER" ]; do
    sleep 5
done
echo "==> Installation ready."

mkdir -p /serverdata

if [ "${MINECRAFT_EULA:-false}" != "true" ]; then
    echo "ERROR: You must accept the Minecraft EULA to run this server." >&2
    echo "        Set MINECRAFT_EULA=true (see https://aka.ms/MinecraftEULA) and restart." >&2
    exit 1
fi
echo "eula=true" > /serverdata/eula.txt

cp /opt/start-server.sh "$PAPER_INSTALL_DIR/start-server.sh"
chmod +x "$PAPER_INSTALL_DIR/start-server.sh"

echo "==> Starting Minecraft (Paper) server on port ${MINECRAFT_PORT:-25565} in tmux session '$TMUX_SESSION'..."
tmux new-session -d -s "$TMUX_SESSION" -c /serverdata "$PAPER_INSTALL_DIR/start-server.sh"

SHUTDOWN_TIMEOUT="${MINECRAFT_SHUTDOWN_TIMEOUT:-30}"

shutdown_server() {
    echo "==> Shutdown requested, sending SIGTERM to server process group..."
    PANE_PID=$(tmux list-panes -t "$TMUX_SESSION" -F "#{pane_pid}" 2>/dev/null)
    [ -n "$PANE_PID" ] && kill -TERM "-$PANE_PID" 2>/dev/null
    ELAPSED=0
    while tmux has-session -t "$TMUX_SESSION" 2>/dev/null && [ "$ELAPSED" -lt "$SHUTDOWN_TIMEOUT" ]; do
        sleep 2
        ELAPSED=$((ELAPSED + 2))
    done
    tmux kill-session -t "$TMUX_SESSION" 2>/dev/null
    exit 0
}

trap shutdown_server SIGTERM SIGINT

# Attach to server console: docker exec -it minecraft tmux attach -t minecraft
while tmux has-session -t "$TMUX_SESSION" 2>/dev/null; do
    sleep 5 & wait $!
done

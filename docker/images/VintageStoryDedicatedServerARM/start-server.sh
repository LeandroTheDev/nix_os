#!/bin/sh
# VS_ARGS - extra arguments passed to VintagestoryServer.dll

SCRIPT_DIR="$(dirname "$(realpath "$0")")"

if [ -f "$SCRIPT_DIR/fonts.conf" ]; then
    export FONTCONFIG_FILE="$SCRIPT_DIR/fonts.conf"
fi

cd "$SCRIPT_DIR"

SERVER_PID=""
STOPPING=false

handle_term() {
    STOPPING=true
    [ -n "$SERVER_PID" ] && kill -TERM "$SERVER_PID" 2>/dev/null
}

trap handle_term TERM

while true; do
    dotnet VintagestoryServer.dll \
        --dataPath /serverdata \
        ${VS_ARGS:-} &
    SERVER_PID=$!
    wait $SERVER_PID
    rc=$?
    # If signaled, dotnet may still be saving — wait for it to fully exit
    if $STOPPING && kill -0 "$SERVER_PID" 2>/dev/null; then
        wait "$SERVER_PID" 2>/dev/null
    fi
    SERVER_PID=""

    if $STOPPING || [ "$rc" -eq 0 ]; then
        echo "==> Server exited cleanly (exit $rc), not restarting."
        break
    fi
    echo "==> Server crashed (exit $rc), restarting in 5 seconds..."
    sleep 5
done

#!/bin/sh
# VS_ARGS - extra arguments passed to VintagestoryServer.dll

SCRIPT_DIR="$(dirname "$(realpath "$0")")"

if [ -f "$SCRIPT_DIR/fonts.conf" ]; then
    export FONTCONFIG_FILE="$SCRIPT_DIR/fonts.conf"
fi

cd "$SCRIPT_DIR"

while true; do
    dotnet VintagestoryServer.dll \
        --dataPath /serverdata \
        ${VS_ARGS:-}
    rc=$?

    if [ "$rc" -eq 0 ]; then
        echo "==> Server exited cleanly (exit $rc), not restarting."
        break
    fi
    echo "==> Server crashed (exit $rc), restarting in 5 seconds..."
    sleep 5
done

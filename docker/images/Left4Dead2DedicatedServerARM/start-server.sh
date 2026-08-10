#!/bin/sh
# L4D2_PORT        - server port
# L4D2_MAXPLAYERS  - max players
# L4D2_MAP         - starting map and game mode (e.g. "c5m1_waterfront versus")
# L4D2_GAMETYPES   - sv_gametypes value
# L4D2_GAMEMODE    - mp_gamemode value
# L4D2_ARGS        - extra arguments passed directly to srcds_linux

while true; do
    set -- \
        -console \
        -norestart \
        -game left4dead2 \
        -secure \
        -ip 0.0.0.0 \
        -port "${L4D2_PORT:-27015}" \
        +maxplayers "${L4D2_MAXPLAYERS:-8}" \
        +map "${L4D2_MAP:-c1m1_hotel}"

    [ -n "${L4D2_GAMETYPES:-}" ] && set -- "$@" +sv_gametypes "$L4D2_GAMETYPES"
    [ -n "${L4D2_GAMEMODE:-}"  ] && set -- "$@" +mp_gamemode  "$L4D2_GAMEMODE"

    eval "set -- \"\$@\" ${L4D2_ARGS:-}"

    LD_LIBRARY_PATH="$(pwd):$(pwd)/bin:$(pwd)/linux32:$(pwd)/bin/linux32:${LD_LIBRARY_PATH:-}" \
    FEX ./srcds_linux "$@"

    EXIT_CODE=$?
    if [ "$EXIT_CODE" -eq 0 ]; then
        echo "==> Server exited cleanly (exit 0), not restarting."
        break
    fi
    echo "==> Server crashed (exit $EXIT_CODE), restarting in 5 seconds..."
    sleep 5
done

#!/bin/sh
# NMRIH_PORT        - server port
# NMRIH_MAXPLAYERS  - max players
# NMRIH_MAP         - starting map (e.g. "nmo_broadway")
# NMRIH_ARGS        - extra arguments passed directly to srcds_linux

while true; do
    set -- \
        -console \
        -norestart \
        -game nmrih \
        -secure \
        -ip 0.0.0.0 \
        -port "${NMRIH_PORT:-27015}" \
        +maxplayers "${NMRIH_MAXPLAYERS:-8}" \
        +map "${NMRIH_MAP:-nmo_broadway}"

    eval "set -- \"\$@\" ${NMRIH_ARGS:-}"

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

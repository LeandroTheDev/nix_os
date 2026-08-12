#!/bin/sh
# TF2_PORT        - server port
# TF2_MAXPLAYERS  - max players
# TF2_MAP         - starting map (e.g. "ctf_2fort")
# TF2_ARGS        - extra arguments passed directly to srcds_linux

while true; do
    set -- \
        -console \
        -norestart \
        -game tf \
        -secure \
        -ip 0.0.0.0 \
        -port "${TF2_PORT:-27015}" \
        +maxplayers "${TF2_MAXPLAYERS:-24}" \
        +map "${TF2_MAP:-ctf_2fort}"

    eval "set -- \"\$@\" ${TF2_ARGS:-}"

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

#!/bin/sh
while true; do
    LD_LIBRARY_PATH="$(pwd):$(pwd)/bin:$(pwd)/linux32:$(pwd)/bin/linux32:${LD_LIBRARY_PATH}" \
    FEX ./srcds_linux \
        -console \
        -norestart \
        -game left4dead2 \
        -ip 0.0.0.0 \
        -port "${L4D2_PORT:-27015}" \
        +maxplayers "${L4D2_MAXPLAYERS:-4}" \
        +map "${L4D2_MAP:-c1m1_hotel}"

    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        echo "==> Server exited cleanly (exit 0), not restarting."
        break
    fi
    echo "==> Server crashed (exit $EXIT_CODE), restarting in 5 seconds..."
    sleep 5
done

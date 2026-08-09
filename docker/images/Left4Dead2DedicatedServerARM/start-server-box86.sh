#!/bin/sh
# Fix Steam connection issues
export BOX86_AES=0
export BOX86_SHAEXT=0
export BOX86_AVX=0
# Fix multi-threaded race conditions in Source Engine
export BOX86_DYNAREC_STRONGMEM=1
export BOX86_DYNAREC_SAFEFLAGS=1
# Emulate x86 PAUSE with ARM YIELD to avoid spinlock race conditions
export BOX86_DYNAREC_PAUSE=1
# Use safer memory barriers
export BOX86_DYNAREC_WEAKBARRIER=0

while true; do
    BOX86_LD_LIBRARY_PATH="$(pwd):$(pwd)/bin:$(pwd)/linux32:$(pwd)/bin/linux32:${BOX86_LD_LIBRARY_PATH}" \
    box86 ./srcds_linux \
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

#!/bin/sh
# Fix Steam Connections
export BOX64_AES=0
export BOX64_SHAEXT=0
export BOX64_AVX=0
# Fix Java JIT Crashes
export BOX64_JVM=1
export BOX64_DYNAREC_CALLRET=0
export BOX64_DYNAREC_SAFEFLAGS=2
# Fix G1 GC parallel thread crashes (SIGSEGV in trim_queue_to_threshold)
# BOX64_JVM=1 only sets STRONGMEM=1; level 3 adds barriers more frequently,
# closer to x86 TSO which G1 GC work-stealing depends on. ONLY ENABLE IF THE CRASHES ARE WAY TO COMMON THE PERFORMANCE IMPACT IS BIG!
export BOX64_DYNAREC_STRONGMEM=2
# Emulate x86 PAUSE (used in GC spinlocks) with ARM YIELD to avoid race conditions
export BOX64_DYNAREC_PAUSE=1
# Use safer (slower) memory barriers instead of weak ones
export BOX64_DYNAREC_WEAKBARRIER=0

while true; do
    BOX64_LD_LIBRARY_PATH="$(pwd)/linux64:$(pwd)/jre64/lib/amd64:.:bin/:${BOX64_LD_LIBRARY_PATH}" \
    box64 ./jre64/bin/java \
        -Djava.awt.headless=true \
        -Xmx${PZ_MEMORY:-2g} \
        -Dzomboid.steam=1 \
        -Dzomboid.znetlog=1 \
        -Djava.library.path=linux64/:natives/ \
        -Djava.library.path=linux64/ \
        -Djava.security.egd=file:/dev/urandom \
        -XX:+UseG1GC \
        -XX:ParallelGCThreads=1 \
        -XX:TieredStopAtLevel=2 \
        -XX:CICompilerCount=1 \
        -XX:-OmitStackTraceInFastThrow \
        -cp "java/.:java/projectzomboid.jar" \
        zombie/network/GameServer

    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        echo "==> Server exited cleanly (exit 0), not restarting."
        break
    fi
    echo "==> Server crashed (exit $EXIT_CODE), restarting in 5 seconds..."
    sleep 5
done

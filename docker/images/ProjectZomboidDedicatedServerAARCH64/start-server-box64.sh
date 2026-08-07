#!/bin/sh
# Fix Steam Connections
export BOX64_AES=0
export BOX64_SHAEXT=0
export BOX64_AVX=0
# Fix Java JIT Crashes
export BOX64_JVM=1
export BOX64_DYNAREC_CALLRET=0
export BOX64_DYNAREC_SAFEFLAGS=2

BOX64_LD_LIBRARY_PATH="$(pwd)/linux64:$(pwd)/jre64/lib/amd64:.:bin/:${BOX64_LD_LIBRARY_PATH}" \
exec box64 ./jre64/bin/java \
    -Djava.awt.headless=true \
    -Xmx${PZ_MEMORY:-2g} \
    -Dzomboid.steam=1 \
    -Dzomboid.znetlog=1 \
    -Djava.library.path=linux64/:natives/ \
    -Djava.library.path=linux64/ \
    -Djava.security.egd=file:/dev/urandom \
    -XX:+UseG1GC \
    -XX:TieredStopAtLevel=2 \
    -XX:CICompilerCount=1 \
    -XX:-OmitStackTraceInFastThrow \
    -cp "java/.:java/projectzomboid.jar" \
    zombie/network/GameServer
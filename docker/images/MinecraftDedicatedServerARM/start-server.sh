#!/bin/sh
# MINECRAFT_JAVA_ARGS - JVM flags (heap size, GC, etc), applied before -jar
# MINECRAFT_ARGS      - extra arguments passed to paper.jar

cd /serverdata

SERVER_PID=""
STOPPING=false

handle_term() {
    STOPPING=true
    [ -n "$SERVER_PID" ] && kill -TERM "$SERVER_PID" 2>/dev/null
}

trap handle_term TERM

while true; do
    java ${MINECRAFT_JAVA_ARGS:--Xms1G -Xmx2G} -jar /home/admin/app/paper/paper.jar \
        --nogui \
        ${MINECRAFT_ARGS:-} &
    SERVER_PID=$!
    wait $SERVER_PID
    rc=$?
    SERVER_PID=""

    if $STOPPING || [ "$rc" -eq 0 ]; then
        echo "==> Server exited cleanly (exit $rc), not restarting."
        break
    fi
    echo "==> Server crashed (exit $rc), restarting in 5 seconds..."
    sleep 5
done

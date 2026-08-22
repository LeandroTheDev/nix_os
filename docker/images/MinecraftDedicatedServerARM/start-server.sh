#!/bin/sh
# MINECRAFT_JAVA_ARGS - JVM flags (heap size, GC, etc), applied before -jar
# MINECRAFT_ARGS      - extra arguments passed to paper.jar

cd /serverdata

while true; do
    java ${MINECRAFT_JAVA_ARGS:--Xms1G -Xmx2G} -jar /home/admin/app/paper/paper.jar \
        --nogui \
        ${MINECRAFT_ARGS:-}

    rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "==> Server exited cleanly (exit 0), not restarting."
        break
    fi
    echo "==> Server crashed (exit $rc), restarting in 5 seconds..."
    sleep 5
done

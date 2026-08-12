#!/usr/bin/env bash
set -euo pipefail

mapfile -t names < <(docker ps -a --format '{{.Names}}')

if [ "${#names[@]}" -eq 0 ]; then
    echo "No containers found."
    exit 1
fi

echo "Containers:"
echo
i=1
for name in "${names[@]}"; do
    image=$(docker inspect --format '{{.Config.Image}}' "$name")
    status=$(docker inspect --format '{{.State.Status}}' "$name")
    echo "  $i) $name ($image) [$status]"
    i=$((i+1))
done
echo

read -rp "Select the container number: " choice

if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#names[@]}" ]; then
    echo "Invalid selection."
    exit 1
fi

target="${names[$((choice-1))]}"

read -rp "How many lines? [100]: " lines
lines="${lines:-100}"

echo "Logs for '$target' (last $lines lines)..."
echo
docker logs --tail "$lines" -t "$target"

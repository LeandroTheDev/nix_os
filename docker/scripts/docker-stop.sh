#!/usr/bin/env bash
set -euo pipefail

mapfile -t names < <(docker ps --format '{{.Names}}')

if [ "${#names[@]}" -eq 0 ]; then
    echo "No running containers."
    exit 1
fi

echo "Running containers:"
echo
i=1
for name in "${names[@]}"; do
    image=$(docker inspect --format '{{.Config.Image}}' "$name")
    echo "  $i) $name ($image)"
    i=$((i+1))
done
echo

read -rp "Select the container number: " choice

if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#names[@]}" ]; then
    echo "Invalid selection."
    exit 1
fi

target="${names[$((choice-1))]}"

echo "Stopping '$target'..."
docker stop "$target"

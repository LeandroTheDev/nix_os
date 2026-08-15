#!/usr/bin/env bash
set -euo pipefail

read -rp "Image to pull: " PULL_IMAGE
docker pull "$PULL_IMAGE"

read -rp "Tag name: " TAG_NAME
docker tag "$PULL_IMAGE" "$TAG_NAME"

echo "Done: $PULL_IMAGE -> $TAG_NAME"

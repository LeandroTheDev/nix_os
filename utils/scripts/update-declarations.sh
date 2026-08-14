#!/usr/bin/env bash
set -euo pipefail

cd /etc/nixos

sudo git pull

sudo nixos-rebuild switch

- ``DECLARE`` box86.nix
- mkdir ~/Steam && cd ~/Steam
- curl -sqL "https://client-update.steamstatic.com/installer/steamcmd_linux.tar.gz" | tar zxvf -
- vim steamcmd-arm.sh
```bash
#!/usr/bin/env bash
set -euo pipefail

STEAMROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STEAMEXE="${STEAMROOT}/linux32/steamcmd"

export LD_LIBRARY_PATH="${STEAMROOT}/linux32:${LD_LIBRARY_PATH:-}"

if command -v box86 >/dev/null 2>&1; then
    exec box86 "$STEAMEXE" "$@"
else
    echo "Error: missing box86 in the PATH." >&2
    exit 1
fi
```
chmod +x steamcmd-arm.sh
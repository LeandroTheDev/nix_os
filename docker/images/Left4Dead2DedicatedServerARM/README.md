# Left 4 Dead 2 Dedicated Server ARM
Running Left 4 Dead 2 dedicated server on ARM devices via FEX (x86-64 emulation).

# Downloading the Image
Get the latest pull command at:
https://github.com/LeansBoboDev/nix_os/pkgs/container/left4dead2-dedicated-server-arm

Example:
```bash
docker pull ghcr.io/leansbobodev/left4dead2-dedicated-server-arm:sha-????
```

# Using the Image

This image uses two modes controlled by `L4D2_MODE`:
- `init` — downloads/updates L4D2 via SteamCMD, then exits
- `server` — starts the game server (default)

## Quick Start (single server)

1. Install L4D2 (only needed once, or to update):
```bash
docker run -it --rm \
  -e L4D2_MODE=init \
  -e STEAM_USERNAME=your_steam_username \
  -v l4d2-data:/home/admin/app/l4d2server \
  -v steamcmd-data:/home/admin/app/steamcmd \
  ghcr.io/leansbobodev/left4dead2-dedicated-server-arm:sha-????
```
> Valve requires an authenticated Steam login to download the dedicated server. You will be prompted for your password and Steam Guard code interactively.

2. Run the server:
```bash
docker run -dit \
  --name l4d2-versus \
  -e L4D2_PORT=27015 \
  -e L4D2_MAXPLAYERS=8 \
  -e L4D2_MAP="c5m1_waterfront versus" \
  -e L4D2_GAMETYPES=versus \
  -e L4D2_GAMEMODE=versus \
  -p 27015:27015/udp \
  -p 27015:27015/tcp \
  -v l4d2-data:/home/admin/app/l4d2server \
  ghcr.io/leansbobodev/left4dead2-dedicated-server-arm:sha-????
```

3. Attach to the server console:
```bash
docker exec -it l4d2-versus tmux attach -t l4d2
# Ctrl+B then D to detach without stopping the server
```

4. View logs:
```bash
docker logs -f l4d2-versus
```

## Multi-server with Docker Compose

The included `docker-compose.yml` runs five game modes simultaneously, each pinned to its own CPU core, sharing a single L4D2 installation on disk.

1. Copy `.env.example` to `.env` and fill in your Steam username:
```bash
cp .env.example .env
```

2. Build the image:
```bash
docker compose build
```

3. Install L4D2 (runs once, then exits):
```bash
docker compose run --rm l4d2-init
```

4. Start all servers:
```bash
docker compose up -d
```

To swap coop for scavenge on port 27019:
```bash
docker compose stop l4d2-coop
docker compose --profile scavenge up -d l4d2-scavenge
```

# Environment Variables

| Variable | Description | Default |
|---|---|---|
| `L4D2_MODE` | `init` to install, `server` to run | `server` |
| `L4D2_PORT` | Server port | `27015` |
| `L4D2_MAXPLAYERS` | Max players | `8` |
| `L4D2_MAP` | Starting map and game mode (e.g. `c5m1_waterfront versus`) | `c1m1_hotel` |
| `L4D2_GAMETYPES` | `sv_gametypes` value | — |
| `L4D2_GAMEMODE` | `mp_gamemode` value | — |
| `L4D2_ARGS` | Extra arguments passed directly to `srcds_linux` | — |
| `L4D2_STARTUP_TIMEOUT` | Seconds to wait for server startup before restarting | `120` |
| `L4D2_SHUTDOWN_TIMEOUT` | Seconds to wait for graceful shutdown before force-kill | `30` |
| `STEAM_USERNAME` | Steam account used by the init container to download L4D2 | — |

# Compiling
Use the `buildImage.sh` script and you are good to go.

# Final Observations
- The install volume (`l4d2-data`) is shared across all game mode containers — only one copy of the ~20 GB game files is stored on disk.
- The container has a graceful shutdown system: when stopped (`docker stop`), it sends `quit` to the server console and waits up to `L4D2_SHUTDOWN_TIMEOUT` seconds before force-killing. If stopping manually, pass enough time:
  ```bash
  docker stop --time 40 l4d2-versus
  ```
- A startup watchdog monitors the server after launch. If the server does not connect to Steam within `L4D2_STARTUP_TIMEOUT` seconds, the tmux session is killed and Docker restarts the container automatically. This guards against FEX hangs on first run.
- CPU pinning is configured via `cpuset` in `docker-compose.yml` (maps to `--cpuset-cpus`). Adjust the core assignments to match your hardware.

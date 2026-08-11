# Left 4 Dead 2 Dedicated Server ARM
Running Left 4 Dead 2 dedicated server on ARM devices via FEX (x86-64 emulation).

# Downloading the Image
Get the latest pull command at:
https://github.com/LeansBoboDev/nix_os/pkgs/container/left4dead2-dedicated-server-arm

Example:
```bash
docker pull ghcr.io/leansbobodev/left4dead2-dedicated-server-arm:sha-????
```

> The local image name (used by `buildImage.sh` and `docker-compose.yml`) is `left4dead2dedicatedserverarm`.

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
  -v steam-home:/home/admin/Steam \
  ghcr.io/leansbobodev/left4dead2-dedicated-server-arm:sha-????
```
> Valve requires an authenticated Steam login to download the dedicated server. You will be prompted for your password and Steam Guard code interactively the first time. The `steam-home` volume caches that login session, so future re-runs (e.g. to update the server) won't ask again.

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

1. Build the image:
```bash
docker compose build
```

2. Install L4D2 (runs once, then exits). `STEAM_USERNAME` must be set in the environment — it is not prompted for interactively, only your password/Steam Guard code is:
```bash
STEAM_USERNAME=your_steam_username docker compose run --rm l4d2-init
```
> Valve requires an authenticated Steam login to download the dedicated server. You will be prompted for your password and Steam Guard code interactively the first time. That login session is cached in the `steam-home` volume, so future re-runs (e.g. to update the server) authenticate automatically without a human present.

3. Start all servers:
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

# Removing the Image

Deleting the image alone does **not** free the disk space used by the game files (~20 GB) — the Docker-managed volumes (`l4d2-data`, `steamcmd-data`, `steam-home`) must be removed explicitly.

## With Docker Compose

```bash
docker compose down --volumes --rmi all
```

`--volumes` removes all Docker-managed volumes (game install, SteamCMD, Steam session cache). `--rmi all` removes the local image.


# Compiling
Use the `buildImage.sh` script and you are good to go. It walks you through the whole setup interactively:

1. Path to the `docker-compose.yml` to use (defaults to the one next to the script — point it elsewhere if you're running a customized/renamed copy, e.g. on a server with a different project name).
2. Whether to (re)build the image, if one already exists locally.
3. **Name of the SteamCMD init service** — defaults to `l4d2-init` (the name used in this repo's `docker-compose.yml`). If your compose file renamed that service (e.g. `left4dead2-init-aionthera` for a multi-instance setup), enter that name here so the script can find it.
4. Your Steam username, to install/update L4D2 via that init service.

It then starts all the game server services defined in the compose file.

# Final Observations
- The install volume (`l4d2-data`) is shared across all game mode containers — only one copy of the ~20 GB game files is stored on disk.
- The container has a graceful shutdown system: when stopped (`docker stop`), it sends `quit` to the server console and waits up to `L4D2_SHUTDOWN_TIMEOUT` seconds before force-killing. If stopping manually, pass enough time:
  ```bash
  docker stop --time 40 l4d2-versus
  ```
- A startup watchdog monitors the server after launch. If the server does not connect to Steam within `L4D2_STARTUP_TIMEOUT` seconds, the tmux session is killed and Docker restarts the container automatically. This guards against FEX hangs on first run.
- CPU pinning is configured via `cpuset` in `docker-compose.yml` (maps to `--cpuset-cpus`). Adjust the core assignments to match your hardware.

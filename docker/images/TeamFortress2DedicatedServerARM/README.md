# Team Fortress 2 Dedicated Server ARM
Running Team Fortress 2 (TF2) dedicated server on ARM devices via FEX (x86-64 emulation).

TF2 is free-to-play, so unlike the Left 4 Dead 2 image in this repo, installing it does **not**
require a Steam account — the init container logs in to SteamCMD anonymously.

# Downloading the Image
Get the latest pull command at:
https://github.com/LeansBoboDev/nix_os/pkgs/container/teamfortress2-dedicated-server-arm

Example:
```bash
docker pull ghcr.io/leansbobodev/teamfortress2-dedicated-server-arm:sha-????
```

> The local image name (used by `buildImage.sh` and `docker-compose.yml`) is `teamfortress2dedicatedserverarm`.

# Using the Image

This image uses two modes controlled by `TF2_MODE`:
- `init` — downloads/updates TF2 via SteamCMD (anonymous login), then exits
- `server` — starts the game server (default)

## Quick Start (single server)

1. Install TF2 (only needed once, or to update). No Steam account needed:
```bash
docker run -it --rm \
  -e TF2_MODE=init \
  -v tf2-data:/home/admin/app/tf2server \
  -v steamcmd-data:/home/admin/app/steamcmd \
  ghcr.io/leansbobodev/teamfortress2-dedicated-server-arm:sha-????
```

2. Run the server:
```bash
docker run -dit \
  --name tf2-2fort \
  -e TF2_PORT=27015 \
  -e TF2_MAXPLAYERS=24 \
  -e TF2_MAP=ctf_2fort \
  -p 27015:27015/udp \
  -p 27015:27015/tcp \
  -v tf2-data:/home/admin/app/tf2server \
  ghcr.io/leansbobodev/teamfortress2-dedicated-server-arm:sha-????
```

3. Attach to the server console:
```bash
docker exec -it tf2-2fort tmux attach -t tf2
# Ctrl+B then D to detach without stopping the server
```

4. View logs:
```bash
docker logs -f tf2-2fort
```

## Multi-server with Docker Compose

The included `docker-compose.yml` runs multiple map instances simultaneously, sharing a single
TF2 installation on disk.

1. Build the image:
```bash
docker compose build
```

2. Install TF2 (runs once, then exits). No credentials needed — the init service logs in to
   SteamCMD anonymously:
```bash
docker compose run --rm tf2-init
```

3. Start all servers:
```bash
docker compose up -d
```

To bring up the optional Hightower instance on port 27019:
```bash
docker compose --profile hightower up -d tf2-hightower
```

# Environment Variables

| Variable | Description | Default |
|---|---|---|
| `TF2_MODE` | `init` to install, `server` to run | `server` |
| `TF2_PORT` | Server port | `27015` |
| `TF2_MAXPLAYERS` | Max players | `24` |
| `TF2_MAP` | Starting map (e.g. `ctf_2fort`) | `ctf_2fort` |
| `TF2_ARGS` | Extra arguments passed directly to `srcds_linux` | — |
| `TF2_STARTUP_TIMEOUT` | Seconds to wait for server startup before restarting | `120` |
| `TF2_SHUTDOWN_TIMEOUT` | Seconds to wait for graceful shutdown before force-kill | `30` |

# Compiling
Use the `buildImage.sh` script and you are good to go. It walks you through the whole setup interactively:

1. Path to the `docker-compose.yml` to use (defaults to the one next to the script — point it elsewhere if you're running a customized/renamed copy, e.g. on a server with a different project name).
2. Whether to (re)build the image, if one already exists locally.
3. **Name of the SteamCMD init service** — defaults to `tf2-init` (the name used in this repo's `docker-compose.yml`). If your compose file renamed that service, enter that name here so the script can find it.

No Steam credentials are prompted for — installation uses an anonymous SteamCMD login. It then
starts all the game server services defined in the compose file.

# Final Observations
- The install volume (`tf2-data`) is shared across all map instances — only one copy of the game files is stored on disk.
- The container has a graceful shutdown system: when stopped (`docker stop`), it sends `quit` to the server console and waits up to `TF2_SHUTDOWN_TIMEOUT` seconds before force-killing. If stopping manually, pass enough time:
  ```bash
  docker stop --time 40 tf2-2fort
  ```
- A startup watchdog monitors the server after launch. If the server does not connect to Steam within `TF2_STARTUP_TIMEOUT` seconds, the tmux session is killed and Docker restarts the container automatically. This guards against FEX hangs on first run.
- CPU pinning is configured via `cpuset` in `docker-compose.yml`. Adjust or add core assignments to match your hardware.
- Steam App ID `232250` is the TF2 dedicated server; unlike L4D2, no owned license/username is required to download it.

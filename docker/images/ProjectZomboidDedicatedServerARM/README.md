# Project Zomboid Dedicated Server ARM
Running project zomboid dedicated server on arm devices

# Downloading the Image
Get the latest pull command at:
https://github.com/LeansBoboDev/nix_os/pkgs/container/projectzomboid-dedicated-server-arm

Example:
```bash
docker pull ghcr.io/leansbobodev/projectzomboid-dedicated-server-arm:sha-????
```

# Using the Image

The `Zomboid` data folder (world saves, config, admin password) is **external** — it lives on the host, outside the container, bind-mounted at `/home/admin/Zomboid`, so it survives image rebuilds and container recreation. Everything else (the SteamCMD-installed server files) lives in Docker-managed volumes.

## Quick Start (manual `docker run`)

1. Create the data folder and set permissions for the container's `admin` user (UID 1000):
```bash
mkdir -p /path/to/zomboid-data
chown 1000:1000 /path/to/zomboid-data
```

2. Run the container:
```bash
docker run -dit \
  --network host \
  --name my-pz-server \
  -e PZ_MEMORY=4g \
  -v /path/to/zomboid-data:/home/admin/Zomboid \
  ghcr.io/leansbobodev/projectzomboid-dedicated-server-arm:sha-????
```

3. Attach to the server console:
```bash
docker exec -it my-pz-server tmux attach -t zomboid
# Ctrl+B then D to detach without stopping the server
```

> **First run:** On the first startup the server will prompt you to set the admin password.
> You must attach to the tmux session and type the password manually before the server finishes loading.

4. View logs:
```bash
docker logs -f my-pz-server
```

## Using Docker Compose

The included `docker-compose.yml` runs a single server, using `network_mode: host` (same as the manual quick start above — Project Zomboid's networking expects the host's network stack). The game install and SteamCMD live in Docker-managed volumes; only the `Zomboid` data folder is bind-mounted from the host, via the `ZOMBOID_DATA_PATH` environment variable, since it must stay external.

1. Set `ZOMBOID_DATA_PATH` to a path on the host (defaults to `$HOME/Zomboid` if you use `buildImage.sh`), create it, and set permissions for the container's `admin` user (UID 1000):
```bash
export ZOMBOID_DATA_PATH="$HOME/Zomboid"
mkdir -p "$ZOMBOID_DATA_PATH"
chown 1000:1000 "$ZOMBOID_DATA_PATH"
```

2. Build the image:
```bash
docker compose build
```

3. Start the server:
```bash
docker compose up -d
```

4. Attach to the server console:
```bash
docker exec -it pz-server tmux attach -t zomboid
# Ctrl+B then D to detach without stopping the server
```

# Environment Variables

| Variable | Description | Default |
|---|---|---|
| `PZ_MEMORY` | RAM allocated to the server JVM (`-Xmx`) | `2g` |
| `PZ_STARTUP_TIMEOUT` | Seconds to wait for startup confirmation before restarting | `480` |
| `PZ_SHUTDOWN_TIMEOUT` | Seconds to wait for graceful shutdown before force-kill | `60` |
| `ZOMBOID_DATA_PATH` | *(Compose only)* Host path bind-mounted to `/home/admin/Zomboid` — external, must be set before `docker compose up` | — |

# Removing the Image

Deleting the image alone does **not** free the disk space used by the game files — the Docker-managed volumes (SteamCMD and server install) must be removed explicitly.

## With Docker Compose

```bash
docker compose down --volumes --rmi all
```

`--volumes` removes the Docker-managed volumes (SteamCMD, game install). `--rmi all` removes the local image.

> The bind-mounted `Zomboid` data folder (world saves, config, admin password) is **not** touched by Docker. To delete it, remove it manually:
> ```bash
> rm -rf "$ZOMBOID_DATA_PATH"
> ```


# Compiling
- Use the `buildImage.sh` script and you are good to go — it drives the compose file above interactively: which compose file to use, whether to (re)build the image, where the external `Zomboid` data folder lives on the host (creating it and fixing ownership for you), and how much RAM to allocate, then starts the server.

# Final Observations
- If you are running a server on a raspberry pi like me consider pre generating the chunks (the raspberry really strugles generating it) took a hole minute for me to generate the first spawn chunks, but fortunately, after the chunks were generated, the server handled it easily.
- The container has a graceful shutdown system: when stopped (`docker stop`), it sends an Enter to clear any pending input followed by `quit` to the server console, then waits up to 60 seconds for the server to save and exit before forcing a kill. Since saving can take around 1 minute, make sure Docker waits long enough before force-killing the container. `docker-compose.yml` already sets `stop_grace_period: 90s`, so `docker compose stop`/`down` wait long enough. If stopping manually with `docker stop`, pass `--time 90`:
  ```bash
  docker stop --time 90 my-pz-server
  ```
- A startup watchdog monitors the server logs after launch. If neither `Initialising Server Systems` nor `Enter new administrator password` appears within 8 minutes, the server is considered stuck and the container is restarted automatically. Both timeouts are configurable via environment variables: `PZ_STARTUP_TIMEOUT` (seconds, default `480`) and `PZ_SHUTDOWN_TIMEOUT` (seconds, default `60`). (this exists because there is a small chance that box64 freezes)
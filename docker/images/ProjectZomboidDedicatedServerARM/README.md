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

# Compiling
- Use the ``buildImage.sh`` script and you are good to go

# Final Observations
- If you are running a server on a raspberry pi like me consider pre generating the chunks (the raspberry really strugles generating it) took a hole minute for me to generate the first spawn chunks, but fortunately, after the chunks were generated, the server handled it easily.
- The container has a graceful shutdown system: when stopped (`docker stop`), it sends an Enter to clear any pending input followed by `quit` to the server console, then waits up to 60 seconds for the server to save and exit before forcing a kill. Since saving can take around 1 minute, make sure Docker waits long enough before force-killing the container. If using a `docker-compose.yml`, set `stop_grace_period: 90s`. If stopping manually with `docker stop`, pass `--time 90`:
  ```bash
  docker stop --time 90 my-pz-server
  ```
- A startup watchdog monitors the server logs after launch. If neither `Initialising Server Systems` nor `Enter new administrator password` appears within 8 minutes, the server is considered stuck and the container is restarted automatically. Both timeouts are configurable via environment variables: `PZ_STARTUP_TIMEOUT` (seconds, default `480`) and `PZ_SHUTDOWN_TIMEOUT` (seconds, default `60`). (this exists because there is a small chance that box64 freezes)
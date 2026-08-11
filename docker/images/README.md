# Clean everything about docker
- docker system prune -a --volumes

# Remove a container
- docker ps -a
- > List the available containers
- docker rm <container_id>

# Remove an image
- docker images
- > List the available images
- docker rmi <image_id>

# Cleanup
- podman rm -a -f
- > All containers
- podman rmi -a -f
- > All images
- podman system prune -a -f
- > Generic data

# List volumes
- docker volume ls
- > List all volumes
- docker volume ls -f dangling=true
- > List volumes not attached to any container (orphans)

# Check volume size
- docker run --rm -v <volume_name>:/data alpine du -sh /data
- > Mount a volume in a throwaway container and print its size
- docker system df -v
- > Overview of disk usage, includes a per-volume size table

# Verify what a volume contains / who uses it
- docker run --rm -it -v <volume_name>:/data alpine ls -la /data
- > Browse a volume's contents without starting the real service
- docker ps -a --filter volume=<volume_name>
- > List containers (running or stopped) currently using a volume

# Remove a volume
- docker volume rm <volume_name>
- > Fails if the volume is still attached to a container
- docker volume prune
- > Remove all dangling (unused) volumes at once
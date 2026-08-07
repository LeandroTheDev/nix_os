#!/usr/bin/env bash
IMAGE_NAME="debian-vm"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$(docker images -q "$IMAGE_NAME" 2>/dev/null)" ]; then
  echo "Image not found, building..."
  docker build -t "$IMAGE_NAME" "$SCRIPT_DIR" || { echo "Build failed, aborting."; exit 1; }
else
  read -p "Image '$IMAGE_NAME' already exists. Rebuild it? (y/N): " REBUILD_IMAGE
  if [[ "$REBUILD_IMAGE" =~ ^[Yy]$ ]]; then
    echo "Rebuilding image..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR" || { echo "Build failed, aborting."; exit 1; }
  fi
fi

read -p "Enter the name for the container: " CONTAINER_NAME
while [ -z "$CONTAINER_NAME" ]; do
  read -p "Container name cannot be empty, please enter a name: " CONTAINER_NAME
done

if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
  echo "Container already running."
  exit 0
elif docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
  echo "Container stopped, starting..."
  docker start "$CONTAINER_NAME"
  exit 0
fi

read -p "Path to your SSH public key [~/.ssh/id_ed25519.pub]: " SSH_KEY_PATH
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519.pub}"

if [ ! -f "$SSH_KEY_PATH" ]; then
  read -p "Public key not found at $SSH_KEY_PATH. Generate a new keypair there? (y/n): " GEN_KEY
  if [[ "$GEN_KEY" =~ ^[Yy]$ ]]; then
    PRIVATE_KEY_PATH="${SSH_KEY_PATH%.pub}"
    mkdir -p "$(dirname "$PRIVATE_KEY_PATH")"
    ssh-keygen -t ed25519 -f "$PRIVATE_KEY_PATH" -N "" -C "debian-vm" || { echo "Key generation failed, aborting."; exit 1; }
  else
    echo "Aborting, no SSH key available."
    exit 1
  fi
fi
SSH_PUBLIC_KEY="$(cat "$SSH_KEY_PATH")"

read -p "Host port to forward to the VM's SSH (22) [2222]: " SSH_PORT
SSH_PORT="${SSH_PORT:-2222}"

HOST_RAM_MB=$(awk '/MemTotal/ {printf "%.0f", $2/1024}' /proc/meminfo)
HOST_CORES=$(nproc)
echo "Host total RAM: ${HOST_RAM_MB} MB"
echo "Host CPU cores: ${HOST_CORES}"

read -p "VM RAM in MB [2048]: " VM_RAM
VM_RAM="${VM_RAM:-2048}"

read -p "VM CPU cores [2]: " VM_CPUS
VM_CPUS="${VM_CPUS:-2}"

read -p "VM disk size, only applied on first creation [10G]: " VM_DISK_SIZE
VM_DISK_SIZE="${VM_DISK_SIZE:-10G}"

KVM_ARGS=()
if [ -e /dev/kvm ]; then
  KVM_ARGS=(--device /dev/kvm)
fi

echo "Creating container..."
docker run -d \
  --name "$CONTAINER_NAME" \
  "${KVM_ARGS[@]}" \
  -v "${CONTAINER_NAME}-data:/vm/data" \
  -p "${SSH_PORT}:22" \
  -e SSH_PUBLIC_KEY="$SSH_PUBLIC_KEY" \
  -e VM_RAM="$VM_RAM" \
  -e VM_CPUS="$VM_CPUS" \
  -e VM_DISK_SIZE="$VM_DISK_SIZE" \
  "$IMAGE_NAME"

if [ $? -eq 0 ]; then
  echo "Container '$CONTAINER_NAME' created successfully."
  echo "First boot downloads the Debian image and can take a while, check with:"
  echo "  docker logs -f $CONTAINER_NAME"
  echo "Once cloud-init finishes, connect with:"
  echo "  ssh -p $SSH_PORT debian@localhost"
else
  echo "Failed to create container."
  exit 1
fi

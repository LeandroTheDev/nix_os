#!/bin/bash
set -euo pipefail

DATA_DIR=/vm/data
mkdir -p "$DATA_DIR"

DISK_IMG="$DATA_DIR/debian.qcow2"
SEED_ISO="$DATA_DIR/seed.iso"

# 1. Download the Debian cloud image once, persisted in the mounted volume
if [ ! -f "$DISK_IMG" ]; then
    echo "==> Downloading Debian base image..."
    wget -q -O "$DATA_DIR/base.qcow2" "$DEBIAN_IMAGE_URL"
    qemu-img create -f qcow2 -F qcow2 -b "$DATA_DIR/base.qcow2" "$DISK_IMG" "$VM_DISK_SIZE"
fi

# 2. Generate cloud-init seed (SSH key auth only) if not already present
if [ ! -f "$SEED_ISO" ]; then
    echo "==> Generating cloud-init configuration..."

    if [ -z "${SSH_PUBLIC_KEY:-}" ]; then
        echo "ERROR: set SSH_PUBLIC_KEY to your public key (e.g. \$(cat ~/.ssh/id_ed25519.pub))" >&2
        exit 1
    fi

    cat > "$DATA_DIR/user-data" <<EOF
#cloud-config
hostname: debian-vm
users:
  - name: debian
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - ${SSH_PUBLIC_KEY}
ssh_pwauth: false
EOF

    cat > "$DATA_DIR/meta-data" <<EOF
instance-id: debian-vm-01
local-hostname: debian-vm
EOF

    cloud-localds "$SEED_ISO" "$DATA_DIR/user-data" "$DATA_DIR/meta-data"
fi

# 3. Detect KVM availability on the host.
# KVM only accelerates a guest matching the host's own CPU architecture, so it's
# only usable here when the host itself is x86_64.
ACCEL="tcg"
CPU_MODEL="max"
HOST_ARCH="$(uname -m)"
if [ "$HOST_ARCH" = "x86_64" ] && [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    ACCEL="kvm"
    CPU_MODEL="host"
    echo "==> KVM available, using hardware acceleration."
else
    echo "==> KVM not usable (host arch: $HOST_ARCH), falling back to TCG (software emulation, slower)."
fi

# 4. Boot the VM
exec qemu-system-x86_64 \
    -machine type=q35,accel=$ACCEL \
    -cpu $CPU_MODEL \
    -smp "$VM_CPUS" \
    -m "$VM_RAM" \
    -drive file="$DISK_IMG",if=virtio,format=qcow2 \
    -drive file="$SEED_ISO",if=virtio,format=raw \
    -netdev user,id=net0,hostfwd=tcp::${SSH_PORT}-:22 \
    -device virtio-net-pci,netdev=net0 \
    -nographic

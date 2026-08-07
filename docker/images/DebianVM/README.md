# Debian VM (full system, not userspace emulation)

Runs a real Debian 12 kernel inside QEMU system-mode, packaged inside a Docker
container. Unlike `QEMUx86_64` (which uses QEMU userspace/binfmt to run
foreign binaries on the host kernel), this boots an actual Debian cloud image
with its own kernel and exposes SSH access.

## Build

```bash
docker build -t debian-vm .
```

Or use the interactive helper, which builds if needed and creates the container:

```bash
./buildImage.sh
```

## Usage (manual)

```bash
docker run -d \
  --name debian-vm \
  --device /dev/kvm \
  -v debian-vm-data:/vm/data \
  -p 2222:22 \
  -e SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)" \
  debian-vm
```

First boot downloads the Debian cloud image and provisions cloud-init, follow it with:

```bash
docker logs -f debian-vm
```

Then connect:

```bash
ssh -p 2222 debian@localhost
```

## Resizing the disk

The disk size set at creation (`VM_DISK_SIZE`) can be grown later without losing data:

```bash
# 1. Stop the running VM (can't resize a qcow2 file while QEMU has it open)
docker stop debian-vm

# 2. Grow the qcow2 file itself (+10G adds to the current size, or use an
#    absolute size like 20G). Overriding --entrypoint is required, otherwise
#    the image's normal entrypoint.sh runs and just boots the VM again,
#    ignoring the command.
docker run --rm -v debian-vm-data:/vm/data --entrypoint qemu-img debian-vm resize /vm/data/debian.qcow2 +10G

# 3. Start the VM again
docker start debian-vm
```

Debian's cloud image ships with cloud-init's `growpart`/`resizefs` modules
enabled, so the root partition and filesystem usually expand automatically on
that next boot. Confirm with `df -h /` over SSH; if it didn't grow on its own,
do it manually inside the VM:

```bash
sudo growpart /dev/vda 1
sudo resize2fs /dev/vda1
```

## Notes

- `--device /dev/kvm` enables hardware acceleration, but only helps when the
  Docker host's own CPU architecture is x86_64 — KVM can't accelerate a guest
  of a different architecture than the host. On any other host arch (e.g.
  running this on ARM), the entrypoint automatically falls back to TCG
  (software emulation — works, but much slower).
- The VM disk lives in the `debian-vm-data` volume, mounted at `/vm/data`.
  Removing the container keeps the disk; removing the volume wipes the VM.
- Authentication is SSH-key only (`SSH_PUBLIC_KEY` env var), password login is
  disabled.
- Override VM sizing with `-e VM_RAM=4096 -e VM_CPUS=4 -e VM_DISK_SIZE=20G`.
- On first boot, cloud-init enables i386 multiarch and installs
  `libc6:i386`, `libstdc++6:i386`, `lib32gcc-s1`, `zlib1g:i386` — needed to run
  32-bit binaries (e.g. SteamCMD) inside the VM. This only runs once per VM
  (tied to the seed image); it won't re-run on an existing disk in the volume.

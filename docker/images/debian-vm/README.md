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

## Notes

- `--device /dev/kvm` enables hardware acceleration. If the host running Docker
  doesn't expose `/dev/kvm` (e.g. Docker Desktop on Windows/WSL2 without nested
  virtualization), the entrypoint automatically falls back to TCG (software
  emulation — works, but much slower).
- The VM disk lives in the `debian-vm-data` volume, mounted at `/vm/data`.
  Removing the container keeps the disk; removing the volume wipes the VM.
- Authentication is SSH-key only (`SSH_PUBLIC_KEY` env var), password login is
  disabled.
- Override VM sizing with `-e VM_RAM=4096 -e VM_CPUS=4 -e VM_DISK_SIZE=20G`.

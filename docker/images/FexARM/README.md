# Fex ARM

Docker image with [FEX-Emu](https://github.com/FEX-Emu/FEX) compiled from source for running x86 and x86-64 binaries on ARM64 devices (e.g. Raspberry Pi, Oracle ARM, AWS Graviton).

## Build

- Build
```bash
docker build -t fex .
```
- Save
```bash
docker save -o fex.tar fex
```

## Usage
- Add image to docker (you need to have the fex.tar first from the build method or download in releases)
```bash
docker load -i fex.tar
```
- Open it
```bash
docker run -it --rm \
  -v ~/Server:/server \
  fex:latest /bin/bash
```
- Run an x86/x86-64 binary through FEX
```bash
FEX ./game_server
```

## Notes

- FEX is compiled from source in a multi-stage build (`arm64v8/ubuntu:25.04`), keeping only the finished `FEX*` binaries in the runtime image.
- Unlike Box64/Box86, FEX doesn't wrap native ARM64 libraries in place of the x86 ones — it needs a real x86-64 RootFS to run guest binaries against. This image fetches one automatically at build time via `FEXRootFSFetcher` (Ubuntu 24.04, x86-64).
- The image is based on `arm64v8/ubuntu:25.04`.

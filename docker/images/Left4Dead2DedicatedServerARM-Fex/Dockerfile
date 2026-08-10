# === STAGE 1: BUILDER ===
FROM arm64v8/ubuntu:25.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git \
    cmake \
    ninja-build \
    pkg-config \
    ccache \
    clang \
    llvm \
    lld \
    python3 python3-setuptools \
    squashfs-tools squashfuse \
    qt6-base-dev qt6-declarative-dev \
    libc-bin \
    nasm \
    curl \
    sudo \
    fuse3 \
    wget && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /home/fex
# Pinned to FEX-2608, same version used by the FexARM image in this repo.
RUN git clone --recurse-submodules --branch FEX-2608 https://github.com/FEX-Emu/FEX.git && \
    cd FEX && \
    mkdir Build && cd Build && \
    CC=clang CXX=clang++ cmake -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_LINKER=lld \
    -DENABLE_LTO=True \
    -DBUILD_TESTS=False -G Ninja .. && \
    ninja install

# === STAGE 2: RUNNER ===
FROM arm64v8/ubuntu:25.04
ENV DEBIAN_FRONTEND=noninteractive

ENV APP_PATH="/home/admin/app"
ENV FEX_ROOTFS="/home/admin/.local/share/fex-emu/RootFS/Ubuntu_24_04"
ENV L4D2_MAP="c1m1_hotel"
ENV L4D2_PORT="27015"
ENV L4D2_MAXPLAYERS="4"

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libsdl3-0 \
    libssl3t64 \
    squashfuse \
    squashfs-tools \
    fuse3 \
    libc-bin \
    curl \
    sudo \
    tmux \
    vim \
    iputils-ping \
    iproute2 \
    binfmt-support && \
    rm -rf /var/lib/apt/lists/*

# Copy the finished FEX binaries from the builder stage
COPY --from=builder /usr/bin/FEX* /usr/bin/

RUN groupadd -f wheel && \
    echo "%wheel ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    useradd -m -s /bin/bash -G wheel admin && \
    mkdir -p "$APP_PATH" && \
    chown -R admin:admin /home/admin

USER root
RUN echo "root:root" | chpasswd

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

COPY start-server-fex.sh /opt/start-server-fex.sh
RUN chmod +x /opt/start-server-fex.sh

USER admin
WORKDIR /home/admin

# Fetch and extract the x86-64 RootFS during build so no FUSE is required at runtime.
# -x tells FEXRootFSFetcher to call unsquashfs (squashfs-tools must be installed above).
# We then write Config.json explicitly because non-interactive mode can silently skip it
# if unsquashfs was previously unavailable and fell back to squashfs-as-is mode.
RUN FEXRootFSFetcher -y -x --force-ui=tty --distro-name=ubuntu --distro-version=24.04 && \
    ROOTFS_DIR=$(find "${HOME}/.local/share/fex-emu/RootFS" "${HOME}/.fex-emu/RootFS" \
                      -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -1) && \
    [ -n "$ROOTFS_DIR" ] || { echo "ERROR: RootFS not extracted — check squashfs-tools"; exit 1; } && \
    mkdir -p "${HOME}/.fex-emu" && \
    printf '{"Config":{"RootFS":"%s"}}' "$ROOTFS_DIR" > "${HOME}/.fex-emu/Config.json" && \
    echo "FEX configured: $ROOTFS_DIR"

# The stock Ubuntu 24.04 FEX RootFS is tuned for desktop Steam gaming (SDL2, OpenAL,
# Mesa GL, OpenSSL are already in it) but is missing a handful of 32-bit libs that
# SteamCMD and the Source engine dedicated server (srcds_linux, both 32-bit x86)
# need. Top them up inside the guest RootFS via FEXBash (its own real apt/dpkg).
# Run as root (sudo) so the guest apt-get's "are you root" checks pass; -E/env
# preserve FEX_ROOTFS since sudo resets $HOME and FEX's config lookup is per-user.
# The stock RootFS is minbase-stripped and doesn't ship gnupg, so apt-key is
# missing and every repo looks "not signed" to apt. Bootstrap gnupg via one
# insecure fetch, then do the real update+install with signature checks intact.
RUN sudo env FEX_ROOTFS="$FEX_ROOTFS" FEXBash -c "apt-get update -o Acquire::AllowInsecureRepositories=true && \
        apt-get install -y --allow-unauthenticated gnupg && \
        apt-get update && apt-get install -y \
        libcurl4:i386 \
        libtinfo6:i386 \
        liblzma5:i386 \
        libsqlite3-0:i386 \
        libdbus-1-3:i386 \
        libnuma1:i386 \
        libudev1:i386 \
        libbz2-1.0:i386 \
        libfontconfig1:i386 && \
        apt-get clean && rm -rf /var/lib/apt/lists/*"

RUN mkdir -p "$APP_PATH"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]

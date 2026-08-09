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
# Pinned to FEX-2608: includes fixes for AVX signal state save/restore across
# context switches and for "untracked thread handling" (Clone syscall losing
# TLS tracking of new threads) - both directly relevant to JVM workloads
# crashing under JIT with multi-threaded SIGSEGV corruption.
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

RUN apt-get update && apt-get install -y \
    libsdl3-0 \
    libssl3t64 \
    squashfuse \
    squashfs-tools \
    fuse3 \
    libc-bin \
    curl \
    sudo \
    wget \
    vim \
    nano \
    tmux \
    strace \
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
    ROOTFS_NAME=$(basename "$ROOTFS_DIR") && \
    mkdir -p "${HOME}/.fex-emu" && \
    printf '{"Config":{"RootFS":"%s"}}' "$ROOTFS_DIR" > "${HOME}/.fex-emu/Config.json" && \
    echo "FEX configured: $ROOTFS_DIR"

CMD ["/bin/bash"]

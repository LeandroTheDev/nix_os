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

RUN apt-get update && apt-get install -y \
    libsdl3-0 \
    libssl3t64 \
    squashfuse \
    libc-bin \
    curl \
    sudo \
    wget \
    vim \
    nano \
    tmux \
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

# Fetch an x86-64 RootFS non-interactively. Unlike Box64/Box86, FEX doesn't
# wrap native ARM64 libraries in place of the x86 ones, it needs a real x86
# userland (glibc, ld.so, etc.) to run guest binaries against.
RUN FEXRootFSFetcher -y -x --force-ui=tty --distro-name=ubuntu --distro-version=24.04

CMD ["/bin/bash"]

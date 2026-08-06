FROM debian:bookworm AS builder
ENV DEBIAN_FRONTEND=noninteractive

# No source is compiled for this image; it runs an amd64 userland through
# the host's QEMU/binfmt emulation, so there is nothing to build here.
# Kept only for structural parity with the other images' builder/runner stages.

# === STAGE 2: RUNNER ===
FROM debian:bookworm
ENV DEBIAN_FRONTEND=noninteractive

ENV APP_PATH="/home/admin/app"

RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    libc6 \
    libstdc++6 \
    zlib1g \
    libgcc-s1 \
    libc6:i386 \
    libstdc++6:i386 \
    libncurses5:i386 \
    libtinfo5:i386 \
    libgcc-s1:i386 \
    lib32gcc-s1 \
    libsdl2-2.0-0:i386 \
    libopenal1:i386 \
    libglib2.0-0:i386 \
    libfontconfig1:i386 \
    libgl1:i386 \
    libgl1-mesa-dri:i386 \
    iputils-ping \
    iproute2 \
    sudo \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN groupadd -f wheel && \
    echo "%wheel ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    useradd -m -s /bin/bash -G wheel admin

USER root
RUN echo "root:root" | chpasswd
USER admin
WORKDIR /home/admin
RUN mkdir -p "$APP_PATH"

CMD ["/bin/bash"]

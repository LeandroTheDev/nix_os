FROM arm64v8/ubuntu:25.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

ENV APP_PATH="/home/admin/app"
# Source Engine library search
ENV BOX64_LD_LIBRARY_PATH=".:bin/:/usr/lib/i386-linux-gnu:/lib/i386-linux-gnu"

RUN dpkg --add-architecture i386 && \
    dpkg --add-architecture armhf && \
    apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    libc6 \
    libstdc++6 \
    zlib1g \
    libgcc-s1 \
    python3 \
    git \
    cmake \
    make \
    build-essential \
    libc6:i386 \
    libstdc++6:i386 \
    libncurses5:i386 \
    libtinfo5:i386 \
    libgcc-s1:i386 \
    gcc-arm-linux-gnueabihf \
    g++-arm-linux-gnueabihf \
    libc6-dev-armhf-cross \
    libc6:armhf \
    libstdc++6:armhf \
    libgcc-s1:armhf \
    libsdl2-2.0-0:i386 \
    libopenal1:i386 \
    libglib2.0-0:i386 \
    libfontconfig1:i386 \
    libgl1:i386 \
    libgl1-mesa-dri:i386 \
    iputils-ping \
    iproute2 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/ptitSeb/box64.git /tmp/box64 && \
    mkdir -p /tmp/box64/build && \
    cd /tmp/box64/build && \
    cmake .. -DARM_DYNAREC=ON -DBOX32=ON -DBOX32_BINFMT=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    rm -rf /tmp/box64

RUN apt-get update && apt-get install -y sudo && apt-get clean && rm -rf /var/lib/apt/lists/* && \
    groupadd -f wheel && \
    echo "%wheel ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    useradd -m -s /bin/bash -G wheel admin && \
    mkdir -p "$APP_PATH" && \
    chown -R admin:admin /home/admin

USER root
RUN echo "root:root" | chpasswd
USER admin
WORKDIR /home/admin

CMD ["/bin/bash"]

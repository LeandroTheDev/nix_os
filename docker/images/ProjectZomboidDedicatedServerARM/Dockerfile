FROM debian:bookworm AS builder
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    git \
    cmake \
    make \
    build-essential \
    crossbuild-essential-armhf \
    python3 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/ptitSeb/box64.git /tmp/box64 && \
    mkdir -p /tmp/box64/build && \
    cd /tmp/box64/build && \
    cmake .. -DARM_DYNAREC=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo && \
    make -j$(nproc) && \
    make install DESTDIR=/box64-install && \
    rm -rf /tmp/box64

# box86 runs x86 32bit (SteamCMD) natively as an ARM 32bit (armhf) process,
# instead of going through box64's 32bit compat mode - fewer quirks for
# SteamCMD specifically. It has to be cross-compiled for armhf even though
# the rest of this image is arm64.
RUN git clone https://github.com/ptitSeb/box86.git /tmp/box86 && \
    mkdir -p /tmp/box86/build && \
    cd /tmp/box86/build && \
    cmake .. \
        -DCMAKE_SYSTEM_NAME=Linux \
        -DCMAKE_SYSTEM_PROCESSOR=arm \
        -DCMAKE_C_COMPILER=arm-linux-gnueabihf-gcc \
        -DCMAKE_CXX_COMPILER=arm-linux-gnueabihf-g++ \
        -DARM_DYNAREC=ON \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo && \
    make -j$(nproc) && \
    make install DESTDIR=/box86-install && \
    rm -rf /tmp/box86

# === STAGE 2: RUNNER ===
FROM debian:bookworm
ENV DEBIAN_FRONTEND=noninteractive

ENV APP_PATH="/home/admin/app"
# RAM allocated to the Project Zomboid server JVM (-Xmx), override with -e PZ_MEMORY=4g
ENV PZ_MEMORY="2g"
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
    libc6:i386 \
    libstdc++6:i386 \
    libncurses6:i386 \
    libtinfo6:i386 \
    libgcc-s1:i386 \
    libcurl4:i386 \
    libssl3:i386 \
    zlib1g:i386 \
    liblzma5:i386 \
    libsqlite3-0:i386 \
    libdbus-1-3:i386 \
    libnuma1:i386 \
    libudev1:i386 \
    libbz2-1.0:i386 \
    libsdl2-2.0-0:i386 \
    libopenal1:i386 \
    libglib2.0-0:i386 \
    libfontconfig1:i386 \
    libgl1:i386 \
    libgl1-mesa-dri:i386 \
    libc6:armhf \
    libstdc++6:armhf \
    zlib1g:armhf \
    iputils-ping \
    iproute2 \
    sudo \
    tmux \
    vim \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /box64-install/ /
COPY --from=builder /box86-install/ /
RUN ldconfig

RUN groupadd -f wheel && \
    echo "%wheel ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    useradd -m -s /bin/bash -G wheel admin && \
    mkdir -p "$APP_PATH" && \
    chown -R admin:admin /home/admin

USER root
RUN echo "root:root" | chpasswd

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

COPY start-server-box64.sh /opt/start-server-box64.sh
RUN chmod +x /opt/start-server-box64.sh

USER admin
WORKDIR /home/admin
RUN mkdir -p "$APP_PATH/pzserver" "$APP_PATH/steamcmd"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]

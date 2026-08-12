FROM arm64v8/ubuntu:25.04
ENV DEBIAN_FRONTEND=noninteractive

ENV APP_PATH="/home/admin/app"

RUN apt-get update && apt-get install -y \
    ca-certificates \
    wget \
    curl \
    tmux \
    vim \
    dotnet-runtime-10.0 \
    fontconfig \
    iputils-ping \
    iproute2 && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd -f wheel && \
    echo "%wheel ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    useradd -m -s /bin/bash -G wheel admin && \
    mkdir -p "$APP_PATH" && \
    chown -R admin:admin /home/admin

RUN curl -fsSL \
    https://github.com/LeansBoboDev/vs_updater_tool/releases/download/2.0/vintagestory_updater_linux_arm64 \
    -o /usr/local/bin/vintagestory_updater && \
    chmod +x /usr/local/bin/vintagestory_updater

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

COPY start-server.sh /opt/start-server.sh
RUN chmod +x /opt/start-server.sh

USER admin
WORKDIR /home/admin

RUN mkdir -p "$APP_PATH/vs"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]

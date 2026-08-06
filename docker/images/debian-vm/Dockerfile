FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    cloud-image-utils \
    wget \
    ca-certificates \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /vm

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# VM resources (override with -e on docker run)
ENV VM_RAM=2048
ENV VM_CPUS=2
ENV VM_DISK_SIZE=10G
ENV SSH_PORT=22
ENV DEBIAN_IMAGE_URL=https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2

EXPOSE 22

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

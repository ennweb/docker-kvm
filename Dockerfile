FROM ubuntu:22.04
LABEL org.opencontainers.image.authors="Emre <e@emre.pm>"

RUN \
  DEBIAN_FRONTEND=noninteractive \
  apt-get update && \
  apt-get install -y --no-install-recommends qemu-system-x86 qemu-utils bridge-utils dnsmasq uml-utilities iptables wget net-tools iproute2 && \
  apt-get autoremove -y && \
  apt-get purge -y --auto-remove && \
  rm -rf /var/lib/apt/lists/*

ADD startup.sh /

ENV \
  QEMU_BINARY=qemu-system-x86_64 \
  RAM=2048 \
  SMP=1 \
  CPU=qemu64 \
  DISK_DEVICE=scsi \
  IMAGE=/data/disk-image \
  IMAGE_FORMAT=qcow2 \
  IMAGE_SIZE=10G \
  IMAGE_CACHE=none \
  IMAGE_DISCARD=unmap \
  IMAGE_CREATE=0 \
  ISO_DOWNLOAD=0 \
  NETWORK=tap \
  VNC=none \
  VNC_IP="" \
  VNC_ID=0 \
  VNC_PORT=5500 \
  VNC_SOCK="/data/vnc.sock" \
  TCP_PORTS="" \
  UDP_PORTS="" \
  EXTRA_ARGS="" \
  NAME=""

VOLUME /data

ENTRYPOINT ["/startup.sh"]

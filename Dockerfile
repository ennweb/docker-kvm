FROM ubuntu:21.04
MAINTAINER Emre <e@emre.pm>

RUN \
  DEBIAN_FRONTEND=noninteractive \
  apt-get update && \
  apt-get install -y qemu-system-x86 qemu-utils bridge-utils dnsmasq uml-utilities iptables wget net-tools iproute2 && \
  apt-get autoclean && \
  apt-get autoremove && \
  rm -rf /var/lib/apt/lists/*

ADD startup.sh /

ENV RAM=2048 SMP=1 DISK_DEVICE=scsi IMAGE=/data/disk-image IMAGE_FORMAT=qcow2 \
    IMAGE_SIZE=5G IMAGE_CACHE=none IMAGE_DISCARD=unmap IMAGE_CREATE=0 \
    ISO_DOWNLOAD=0 NETWORK=tap VNC=none VNC_ID=0 VNC_PORT=5500 VNC_SOCK="/data/vnc.sock"

VOLUME /data

ENTRYPOINT ["/startup.sh"]

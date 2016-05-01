FROM ubuntu:14.04.3
MAINTAINER Emre <e@emre.pm>

ENV DEBIAN_FRONTEND noninteractive

RUN \
  echo deb http://ppa.launchpad.net/monotek/qemu-glusterfs-3.7/ubuntu trusty main >> /etc/apt/sources.list && \
  echo deb-src http://ppa.launchpad.net/monotek/qemu-glusterfs-3.7/ubuntu trusty main >> /etc/apt/sources.list && \
  echo deb http://ppa.launchpad.net/gluster/glusterfs-3.7/ubuntu trusty main >> /etc/apt/sources.list && \
  echo deb-src http://ppa.launchpad.net/gluster/glusterfs-3.7/ubuntu trusty main >> /etc/apt/sources.list

RUN \
  echo Package: qemu-common qemu-guest-agent qemu-keymaps qemu-kvm qemu-system-arm qemu-system-common \
    qemu-system-mips qemu-system-ppc qemu-system-misc qemu-system-sparc qemu-system-x86 qemu-system \
    qemu-user-static qemu-user qemu-utils qemu > /etc/apt/preferences.d/qemu && \
  echo Pin: release o=LP-PPA-monotek-qemu-glusterfs-3.7 >> /etc/apt/preferences.d/qemu && \
  echo Pin-Priority: 1000 >> /etc/apt/preferences.d/qemu

RUN \
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 13E01B7B3FE869A9 && \
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 211F871AB39B9849 && \
  apt-get update && \
  apt-get install -y qemu-kvm qemu-utils bridge-utils dnsmasq uml-utilities iptables wget && \
  apt-get autoclean && \
  apt-get autoremove && \
  rm -rf /var/lib/apt/lists/*

ADD startup.sh /

ENV RAM 2048
ENV SMP 1
ENV CPU qemu64
ENV IMAGE /data/disk-image
ENV IMAGE_FORMAT qcow2
ENV IMAGE_SIZE 10G
ENV IMAGE_CACHE none
ENV IMAGE_DISCARD unmap
ENV IMAGE_CREATE 0
ENV ISO_DOWNLOAD 0
ENV NETWORK tap
ENV VNC none
ENV VNC_IP ""
ENV VNC_ID 0
ENV VNC_PORT 5500
ENV VNC_SOCK /data/vnc.sock

VOLUME /data

ENTRYPOINT ["/startup.sh"]

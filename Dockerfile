FROM ubuntu:14.04.2
MAINTAINER Emre <e@emre.pm>

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -y --force-yes --no-install-recommends qemu-kvm supervisor qemu-utils wget bridge-utils dnsmasq
RUN apt-get autoclean && apt-get autoremove && rm -rf /var/lib/apt/lists/*

ADD startup.sh /

ENV RAM 2048
ENV IMAGE /data/disk-image
ENV IMAGE_SIZE 10G
ENV IMAGE_CREATE 0
ENV ISO http://releases.ubuntu.com/14.04.2/ubuntu-14.04.2-desktop-amd64.iso
ENV ISO_FORCE_DOWNLOAD 0
ENV NETWORK bridge
VOLUME /data
ENTRYPOINT ["/startup.sh"]

FROM ubuntu:14.04.2
MAINTAINER Emre <e@emre.pm>

ENV DEBIAN_FRONTEND noninteractive

RUN echo deb http://ppa.launchpad.net/monotek/qemu-glusterfs-3.6/ubuntu trusty main >> /etc/apt/sources.list
RUN echo deb-src http://ppa.launchpad.net/monotek/qemu-glusterfs-3.6/ubuntu trusty main >> /etc/apt/sources.list
RUN echo deb http://ppa.launchpad.net/gluster/glusterfs-3.6/ubuntu trusty main >> /etc/apt/sources.list
RUN echo deb-src http://ppa.launchpad.net/gluster/glusterfs-3.6/ubuntu trusty main >> /etc/apt/sources.list

RUN echo Package: qemu-common qemu-guest-agent qemu-keymaps qemu-kvm qemu-system-arm qemu-system-common \
qemu-system-mips qemu-system-ppc qemu-system-misc qemu-system-sparc qemu-system-x86 qemu-system \
qemu-user-static qemu-user qemu-utils qemu > /etc/apt/preferences.d/qemu
RUN echo Pin: release o=LP-PPA-monotek-qemu-glusterfs-3.6 >> /etc/apt/preferences.d/qemu
RUN echo Pin-Priority: 1000 >> /etc/apt/preferences.d/qemu

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 13E01B7B3FE869A9
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 211F871AB39B9849
RUN apt-get update
RUN apt-get install -y qemu-kvm qemu-utils bridge-utils dnsmasq wget
RUN apt-get autoclean && apt-get autoremove && rm -rf /var/lib/apt/lists/*

ADD startup.sh /

ENV RAM 2048
ENV SMP 1
ENV IMAGE /data/disk-image
ENV IMAGE_SIZE 10G
ENV IMAGE_CREATE 0
ENV ISO_FORCE_DOWNLOAD 0
ENV NETWORK user
VOLUME /data
ENTRYPOINT ["/startup.sh"]

# QEMU/KVM on Docker

## Usage

Boot with ISO
```
docker run -v ${PWD}:/data \
    --cap-add NET_ADMIN \
    --device /dev/kvm:/dev/kvm \
    --device /dev/net/tun:/dev/net/tun \
    -e RAM=2048 \
    -e IMAGE=/data/disk-image \
    -e ISO=http://releases.ubuntu.com/14.04.2/ubuntu-14.04.2-desktop-amd64.iso \
    -p 2222:22 \
    -p 8080:80 \
    ennweb/kvm
```


Boot with glusterfs volume
```
docker run -v ${PWD}:/data \
    --cap-add NET_ADMIN \
    --device /dev/kvm:/dev/kvm \
    --device /dev/net/tun:/dev/net/tun \
    -e RAM=2048 \
    -e IMAGE=glusterfs://server/volume/disk-image.qcow2 \
    -e ISO=glusterfs://server/volume/cd-image.iso \
    -p 2222:22 \
    -p 8080:80 \
    ennweb/kvm
```


Create new volume file
```
docker run -v ${PWD}:/data \
    --cap-add NET_ADMIN \
    --device /dev/kvm:/dev/kvm \
    --device /dev/net/tun:/dev/net/tun \
    -e RAM=2048 \
    -e IMAGE=/data/disk-image \
    -e IMAGE_CREATE=1 \
    -p 2222:22 \
    -p 8080:80 \
    ennweb/kvm
```


This image also provides vnc to access remote desktop via /data/vnc.socket file

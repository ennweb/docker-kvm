# QEMU/KVM on Docker

## Usage

Boot with ISO

```
docker run -v ${PWD}:/data \
    --cap-add NET_ADMIN \
    --device /dev/kvm:/dev/kvm \
    --device /dev/net/tun:/dev/net/tun \
    -e VM_DISK_IMAGE=/data/disk-image \
    -e ISO=http://releases.ubuntu.com/14.04.2/ubuntu-14.04.2-desktop-amd64.iso \
    -p 2222:22 \
    -p 8080:80 \
    ennweb/kvm
```

Turn on machine with last image
```
docker run -v ${PWD}:/data \
    --cap-add NET_ADMIN \
    --device /dev/kvm:/dev/kvm \
    --device /dev/net/tun:/dev/net/tun \
    -e VM_DISK_IMAGE=/data/disk-image \
    -e ISO= \
    -p 2222:22 \
    -p 8080:80 \
    ennweb/kvm
```

This image also provide vnc to access remote desktop via /data/vnc.socket file

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
    -p 16080:6080 \
    -p 15900:5900 \
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
    -p 16080:6080 \
    -p 15900:5900 \
    ennweb/kvm
```

Then browse http://127.0.0.1:16080/

This image also provide *spicec* to access remote desktop if running by *docker run -e REMOTE_ACCESS=spice -p 16080:6080 ...*)
```
sudo apt-get install spice-client
spicec -h 127.0.0.1 -p 15900
```

# QEMU/KVM on Docker

## Usage

Boot with ISO
```
docker run \
    --privileged \
    -v /dev:/dev \
    -v ${PWD}:/data \
    -e RAM=2048 \
    -e SMP=1 \
    -e IMAGE=/data/disk-image \
    -e ISO=http://host/path/cd.iso \
    -e ISO2=http://host/path/drivers.iso \
    -e ISO_DOWNLOAD=1 \
    -e VNC=tcp \
    -p 2222:22 \
    -p 8080:80 \
    -p 5900:5900 \
    ennweb/kvm
```


Boot with glusterfs volume
```
docker run \
    --privileged \
    -v /dev:/dev \
    -v ${PWD}:/data \
    -e RAM=2048 \
    -e SMP=1 \
    -e IMAGE=gluster://server/volume/disk-image.qcow2 \
    -e ISO=gluster://server/volume/cd-image.iso \
    -e VNC=tcp \
    -p 2222:22 \
    -p 8080:80 \
    -p 5900:5900 \
    ennweb/kvm
```


Boot with rbd volume
```
docker run \
    --privileged \
    -v /dev:/dev \
    -v /etc/ceph:/etc/ceph \
    -v /var/lib/ceph:/var/lib/ceph \
    -v ${PWD}:/data \
    -e RAM=2048 \
    -e SMP=1 \
    -e IMAGE=rbd:data/disk-image \
    -e IMAGE_FORMAT=raw \
    -e ISO=rbd:data/cd-image \
    -e VNC=tcp \
    -p 2222:22 \
    -p 8080:80 \
    -p 5900:5900 \
    ennweb/kvm
```


Create new volume file
```
docker run \
    --privileged \
    -v /dev:/dev \
    -v ${PWD}:/data \
    -e RAM=2048 \
    -e SMP=1 \
    -e IMAGE=/data/disk-image \
    -e IMAGE_CREATE=1 \
    -e VNC=tcp \
    -p 2222:22 \
    -p 8080:80 \
    -p 5900:5900 \
    ennweb/kvm
```


## Network modes

`-e NETWORK=bridge --net=host -e NETWORK_BRIDGE=docker0 -e NETWORK_MAC=01:02:03:04:05`
> Bridge mode will be enabled with docker0 interface. `--net=host` is required for this mode. Mac address is optional.

`-e NETWORK=tap`
> Enables NAT and port forwarding with tap device

`-e NETWORK=macvtap --net=host -e NETWORK_IF=eth0 -e NETWORK_BRIDGE=vtap0 -e NETWORK_MAC=01:02:03:04:05`
> Creates a macvtap device called vtap0 and will setup bridge with your external interface eth0. `--net=host` is required for this mode. Mac address is optional.

`-e NETWORK=user -e PORTS=22,80`
> Enables qemu user networking. Also redirects ports 22 and 80 to vm.


## VNC options

`-e VNC=tcp -e VNC_IP=127.0.0.1 -e VNC_ID=1`
> VNC server will listen tcp connections on 127.0.0.1:5901

`-e VNC=sock -e VNC_SOCK=/data/vnc.sock`
> VNC server will listen on unix socket at /data/vnc.sock

`-e VNC=reverse -e VNC_IP=1.1.1.1 -e VNC_PORT=5500`
> Reverse VNC connection to 1.1.1.1:5500

`-e VNC=none`
> VNC server will be disabled

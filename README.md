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

Boot in rootless Podman environment
```
docker run \
    --privileged \
    -v ${PWD}/data:/data \
    -e CPU=Nehalem \
    -e SMP=4 \
    -e RAM=4096 \
    -e ISO=/data/cd-image.iso \
    -e IMAGE_CREATE=1 \
    -e IMAGE=/data/hd-image.qcow2 \
    -e VNC=tcp \
    -p 127.0.0.1:5900:5900 \
    -e NETWORK_IF=tap0 \
    ennweb/kvm
```

## Network modes

`-e NETWORK=bridge --net=host -e NETWORK_BRIDGE=vmbr0 -e NETWORK_MAC=01:02:03:04:05`
> Bridge mode will be enabled with vmbr0 interface. `--net=host` is required for this mode. Mac address is optional.

`-e NETWORK=routed --net=host -e NETWORK_BRIDGE=br-guest -e NETWORK_IP=10.0.0.1 -e NETWORK_ROUTE=123.123.123.123 -e NETWORK_MAC=01:02:03:04:05`
> Routed mode will be enabled with br-guest interface. Bridge device will be created and routed to 123.123.123.123 (can be a list with comma separated IPs). `--net=host` is required for this mode. Mac address is optional. (This mode can be used for OVH/SoYouStart servers with additional IPs)
> Example guest configuration:
> ```
> iface ens4 inet static
>  address 123.123.123.123
>  netmask 255.255.255.255
>  gateway 10.0.0.1
>  dns-nameservers 8.8.8.8
> ```

`-e NETWORK=tap`
> Enables NAT and port forwarding with tap device

`-e NETWORK=macvtap --net=host -e NETWORK_IF=eth0 -e NETWORK_BRIDGE=vtap0 -e NETWORK_MAC=01:02:03:04:05`
> Creates a macvtap device called vtap0 and will setup bridge with your external interface eth0. `--net=host` is required for this mode. Mac address is optional.

`-e NETWORK=user -e TCP_PORTS=22,80`
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

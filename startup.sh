#!/bin/bash

set -e

[ -n "$DEBUG" ] && set -x

# Create the kvm node (required --privileged)
if [ ! -e /dev/kvm ]; then
  set +e
  mknod /dev/kvm c 10 $(grep '\<kvm\>' /proc/misc | cut -f 1 -d' ')
  set -e
fi

# If we were given arguments, override the default configuration
if [ $# -gt 0 ]; then
  exec ${QEMU_BINARY} $@
  exit $?
fi

# mountpoint check
if [ ! -d /data ]; then
  if [ "${ISO:0:1}" != "/" ] || [ -z "$IMAGE" ]; then
    echo "/data not mounted: use -v to mount it"
    exit 1
  fi
fi

if [ -n "$ACCEL" ]; then
  echo "[accel]"
  FLAGS_ACCEL="-accel ${ACCEL}"
  echo "parameter: ${FLAGS_ACCEL}"
else
  $QEMU_BINARY -accel ? | grep -q "kvm" && FLAGS_ACCEL="-accel kvm"
fi

if [ -n "$CPU" ]; then
  echo "[cpu]"
  FLAGS_CPU="-cpu ${CPU}"
  echo "parameter: ${FLAGS_CPU}"
else
  FLAGS_CPU="-cpu qemu64"
fi

if [ -n "$SMP" ]; then
  echo "[smp]"
  FLAGS_SMP="-smp ${SMP}"
  echo "parameter: ${FLAGS_SMP}"
else
  FLAGS_SMP="-smp 1"
fi

if [ -n "$RAM" ]; then
  echo "[ram]"
  FLAGS_RAM="-m ${RAM}"
  echo "parameter: ${FLAGS_RAM}"
else
  FLAGS_RAM="-m 2048"
fi

if [ -n "$ISO" ]; then
  echo "[iso]"
  if [ "${ISO:0:1}" != "/" ] && [ "${ISO:0:4}" != "rbd:" ]; then
    basename=$(basename $ISO)
    if [ ! -f "/data/${basename}" ] || [ "$ISO_DOWNLOAD" != "0" ]; then
      wget -O- "$ISO" > /data/${basename}
    fi
    ISO=/data/${basename}
  fi
  FLAGS_ISO="-drive file=${ISO},media=cdrom,index=2"
  if [ "${ISO:0:4}" != "rbd:" ] && [ ! -f "$ISO" ]; then
    echo "ISO file not found: $ISO"
    exit 1
  fi
  echo "parameter: ${FLAGS_ISO}"
fi

if [ -n "$ISO2" ]; then
  echo "[iso2]"
  if [ "${ISO2:0:1}" != "/" ] && [ "${ISO2:0:4}" != "rbd:" ]; then
    basename=$(basename $ISO2)
    if [ ! -f "/data/${basename}" ] || [ "$ISO_DOWNLOAD" != "0" ]; then
      wget -O- "$ISO2" > /data/${basename}
    fi
    ISO2=/data/${basename}
  fi
  FLAGS_ISO2="-drive file=${ISO2},media=cdrom,index=3"
  if [ "${ISO2:0:4}" != "rbd:" ] && [ ! -f "$ISO2" ]; then
    echo "ISO2 file not found: $ISO2"
    exit 1
  fi
  echo "parameter: ${FLAGS_ISO2}"
fi

echo "[disk image]"
if [ "$IMAGE_CREATE" == "1" ]; then
  qemu-img create -f ${IMAGE_FORMAT} ${IMAGE} ${IMAGE_SIZE}
elif [ "${IMAGE:0:4}" != "rbd:" ] && [ ! -f "$IMAGE" ]; then
  echo "IMAGE not found: ${IMAGE}"; exit 1;
fi
if [ "$DISK_DEVICE" == "scsi" ]; then
  FLAGS_DISK_IMAGE="-device virtio-scsi-pci,id=scsi -drive file=${IMAGE},if=none,id=hd,cache=${IMAGE_CACHE},discard=${IMAGE_DISCARD},index=1 -device scsi-hd,drive=hd"
else
  FLAGS_DISK_IMAGE="-drive file=${IMAGE},if=${DISK_DEVICE},cache=${IMAGE_CACHE},format=${IMAGE_FORMAT},index=1"
fi
echo "parameter: ${FLAGS_DISK_IMAGE}"

if [ -n "$FLOPPY" ]; then
  echo "[floppy image]"
  FLAGS_FLOPPY_IMAGE="-fda ${FLOPPY}"
  echo "parameter: ${FLAGS_FLOPPY_IMAGE}"
fi

echo "[network]"
echo "1" > /proc/sys/net/ipv4/ip_forward
hexchars="0123456789ABCDEF"
NETWORK_IF="${NETWORK_IF:-eth0}"
NETWORK_MAC="${NETWORK_MAC:-$(echo 00:F0$(for i in {1..8} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/:\1/g'))}"
NETWORK_MAC2="${NETWORK_MAC2:-$(echo 00:F0$(for i in {1..8} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/:\1/g'))}"
if [ "$NETWORK" == "bridge" ]; then
  mkdir -p /etc/qemu
  NETWORK_BRIDGE="${NETWORK_BRIDGE:-vmbr0}"
  echo allow $NETWORK_BRIDGE > /etc/qemu/bridge.conf
  FLAGS_NETWORK="-netdev bridge,br=${NETWORK_BRIDGE},id=net0 -device virtio-net,netdev=net0,mac=${NETWORK_MAC}"
elif [ "$NETWORK" == "routed" ]; then
  mkdir -p /etc/qemu
  NETWORK_BRIDGE="${NETWORK_BRIDGE:-vmbr0}"
  NETWORK_IP="${NETWORK_IP:-10.0.0.1}"
  NETWORK_SUB=`echo $NETWORK_IP | cut -f1,2,3 -d\.`
  NETWORK_BROADCAST="${NETWORK_BROADCAST:-$(echo ${NETWORK_SUB}.255)}"
  set +e
  brctl addbr $NETWORK_BRIDGE 2>/dev/null
  if [[ $? -ne 0 ]]; then
    echo "Warning! Bridge interface already exists"
  fi
  set -e
  brctl stp $NETWORK_BRIDGE off
  brctl setfd $NETWORK_BRIDGE 0
  ip addr add $NETWORK_IP/24 brd $NETWORK_BROADCAST scope global dev $NETWORK_BRIDGE 2>/dev/null || true
  ip link set dev $NETWORK_BRIDGE up
  for ip in $(echo $NETWORK_ROUTE | tr "," "\n"); do
    ip route add $ip dev $NETWORK_BRIDGE 2>/dev/null || true
  done
  echo allow $NETWORK_BRIDGE > /etc/qemu/bridge.conf
  FLAGS_NETWORK="-netdev bridge,br=${NETWORK_BRIDGE},id=net0 -device virtio-net,netdev=net0,mac=${NETWORK_MAC}"
elif [ "$NETWORK" == "tap" ]; then
  TAP_IFACE=tap_guest
  IP=`ip addr show dev $NETWORK_IF | grep "inet " | awk '{print $2}' | cut -f1 -d/`
  NAMESERVER=`grep nameserver /etc/resolv.conf | cut -f2 -d ' '`
  NAMESERVERS=`echo ${NAMESERVER[*]} | sed "s/ /,/g"`
  NETWORK_IP="${NETWORK_IP:-$(echo 172.$((RANDOM%(31-16+1)+16)).$((RANDOM%256)).$((RANDOM%(254-2+1)+2)))}"
  NETWORK_SUB=`echo $NETWORK_IP | cut -f1,2,3 -d\.`
  NETWORK_GW="${NETWORK_GW:-$(echo ${NETWORK_SUB}.1)}"
  tunctl -t $TAP_IFACE
  dnsmasq --user=root \
    --dhcp-range=$NETWORK_IP,$NETWORK_IP \
    --dhcp-option=option:router,$NETWORK_GW \
    --dhcp-option=option:dns-server,$NAMESERVERS
  ifconfig $TAP_IFACE $NETWORK_GW up
  iptables -t nat -A POSTROUTING -o $NETWORK_IF -j MASQUERADE
  iptables -I FORWARD 1 -i $TAP_IFACE -j ACCEPT
  iptables -I FORWARD 1 -o $TAP_IFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
  if [ "$VNC" == "tcp" ]; then
    iptables -t nat -A PREROUTING -p tcp -d $IP ! --dport `expr 5900 + $VNC_ID` -j DNAT --to-destination $NETWORK_IP
    iptables -t nat -A PREROUTING -p udp -d $IP -j DNAT --to-destination $NETWORK_IP
    iptables -t nat -A PREROUTING -p icmp -d $IP -j DNAT --to-destination $NETWORK_IP
  else
    iptables -t nat -A PREROUTING -d $IP -j DNAT --to-destination $NETWORK_IP
  fi
  FLAGS_NETWORK="-netdev tap,id=net0,ifname=${TAP_IFACE},vhost=on,script=no,downscript=no -device virtio-net-pci,netdev=net0"
elif [ "$NETWORK" == "macvtap" ]; then
  NETWORK_BRIDGE="${NETWORK_BRIDGE:-vtap0}"
  set +e
  ip link add link $NETWORK_IF name $NETWORK_BRIDGE address $NETWORK_MAC type macvtap mode bridge
  if [[ $? -ne 0 ]]; then
    echo "Warning! Bridge interface already exists"
  fi
  set -e
  FLAGS_NETWORK="-netdev tap,fd=3,id=net0,vhost=on -net nic,vlan=0,netdev=net0,macaddr=$NETWORK_MAC,model=virtio"
  exec 3<> /dev/tap`cat /sys/class/net/$NETWORK_BRIDGE/ifindex`
  ip link set $NETWORK_BRIDGE up
  if [ ! -z "$NETWORK_IF2" ]; then
    NETWORK_BRIDGE2="${NETWORK_BRIDGE2:-vtap1}"
    set +e
    ip link add link $NETWORK_IF2 name $NETWORK_BRIDGE2 address $NETWORK_MAC2 type macvtap mode bridge
    if [[ $? -ne 0 ]]; then
      echo "Warning! Bridge interface 2 already exists"
    fi
    set -e
    FLAGS_NETWORK="${FLAGS_NETWORK} -netdev tap,fd=4,id=net1,vhost=on -net nic,vlan=1,netdev=net1,macaddr=$NETWORK_MAC2,model=virtio"
    exec 4<> /dev/tap`cat /sys/class/net/$NETWORK_BRIDGE2/ifindex`
    ip link set $NETWORK_BRIDGE2 up
  fi
else
  NETWORK="user"
  REDIR=""
  if [ ! -z "$TCP_PORTS" ]; then
    OIFS=$IFS
    IFS=","
    for port in $TCP_PORTS; do
      REDIR+="-redir tcp:${port}::${port} "
    done
    IFS=$OIFS
  fi

  if [ ! -z "$UDP_PORTS" ]; then
    OIFS=$IFS
    IFS=","
    for port in $UDP_PORTS; do
      REDIR+="-redir udp:${port}::${port} "
    done
    IFS=$OIFS
  fi
  FLAGS_NETWORK="-net nic,model=virtio -net user ${REDIR}"
fi
echo "Using ${NETWORK}"
echo "parameter: ${FLAGS_NETWORK}"

echo "[remote access]"
if [ "$VNC" == "tcp" ]; then
  FLAGS_REMOTE_ACCESS="-vnc ${VNC_IP}:${VNC_ID}"
elif [ "$VNC" == "reverse" ]; then
  FLAGS_REMOTE_ACCESS="-vnc ${VNC_IP}:${VNC_PORT},reverse"
elif [ "$VNC" == "sock" ]; then
  FLAGS_REMOTE_ACCESS="-vnc unix:${VNC_SOCK}"
else
  FLAGS_REMOTE_ACCESS="-nographic"
fi
echo "parameter: ${FLAGS_REMOTE_ACCESS}"

if [ -n "$BOOT" ]; then
  echo "[boot]"
  FLAGS_BOOT="-boot ${BOOT}"
  echo "parameter: ${FLAGS_BOOT}"
fi

if [ -n "$KEYBOARD" ]; then
  echo "[keyboard]"
  FLAGS_KEYBOARD="-k ${KEYBOARD}"
  echo "parameter: ${FLAGS_KEYBOARD}"
fi

if [ -n "$KEYBOARD_LAYOUT" ]; then
  echo "[keyboard layout]"
  FLAGS_KEYBOARD_LAYOUT="-k ${KEYBOARD_LAYOUT}"
  echo "parameter: ${FLAGS_KEYBOARD_LAYOUT}"
else
  FLAGS_KEYBOARD_LAYOUT="-k en-us"
fi

if [ -n "$USB_DEVICES" ]; then
  echo "[usb devices]"
  FLAGS_USB_DEVICES="-usb ${USB_DEVICES}"
  echo "parameter: ${FLAGS_USB_DEVICES}"
else
  FLAGS_USB_DEVICES="-usb -usbdevice tablet"
fi

if [ -n "$NAME" ]; then
  echo "[name]"
  FLAGS_NAME="-name $NAME"
  echo "parameter: ${FLAGS_NAME}"
else
  FLAGS_NAME="-name ${HOSTNAME:-guest}"
fi

if [ -n "$EXTRA_ARGS" ]; then
  echo "[extra args]"
  FLAGS_EXTRA="-no-shutdown ${EXTRA_ARGS}"
  echo "parameter: ${EXTRA_ARGS}"
else
  FLAGS_EXTRA="-no-shutdown"
fi

set -x
exec ${QEMU_BINARY} \
  ${FLAGS_ACCEL} \
  ${FLAGS_CPU} \
  ${FLAGS_SMP} \
  ${FLAGS_RAM} \
  ${FLAGS_REMOTE_ACCESS} \
  ${FLAGS_DISK_IMAGE} \
  ${FLAGS_FLOPPY_IMAGE} \
  ${FLAGS_ISO} \
  ${FLAGS_ISO2} \
  ${FLAGS_NETWORK} \
  ${FLAGS_KEYBOARD} \
  ${FLAGS_BOOT} \
  ${FLAGS_KEYBOARD_LAYOUT} \
  ${FLAGS_USB_DEVICES} \
  ${FLAGS_NAME} \
  ${FLAGS_EXTRA}

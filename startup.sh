#!/bin/bash

set -e

[ -n "$DEBUG" ] && set -x

# Create the kvm node (required --privileged)
if [ ! -e /dev/kvm ]; then
  set +e
  mknod /dev/kvm c 10 $(grep '\<kvm\>' /proc/misc | cut -f 1 -d' ')
  set -e
fi

# Pass Docker command args to kvm
KVM_ARGS=$@

# mountpoint check
if [ ! -d /data ]; then
  if [ "${ISO:0:1}" != "/" ] || [ -z "$VM_DISK_IMAGE" ]; then
    echo "/data not mounted: using -v to mount it"
    exit 1
  fi
fi

VM_RAM=${VM_RAM:-2048}
VM_DISK_IMAGE_SIZE=${VM_IMAGE:-10G}

if [ -n "$ISO" ]; then
  echo "[iso]"
  if [ "${ISO:0:1}" != "/" ]; then
    basename=$(basename $ISO)
    if [ ! -f "/data/${basename}" ] || [ "$ISO_FORCE_DOWNLOAD" != "0" ]; then
      wget -O- "$ISO" > /data/${basename}
    fi
    ISO=/data/${basename}
  fi
  FLAGS_ISO="-drive file=${ISO},media=cdrom,index=2"
  if [ ! -f "$ISO" ]; then
    echo "ISO file not found: $ISO"
    exit 1
  fi
fi

echo "[disk image]"
if [ -z "${VM_DISK_IMAGE}" ] || [ "$VM_DISK_IMAGE_CREATE_IF_NOT_EXIST" != "0" ]; then
  KVM_IMAGE=${VM_DISK_IMAGE:-/data/disk-image}
  if [ ! -f "$VM_DISK_IMAGE" ]; then
    qemu-img create -f qcow2 ${KVM_IMAGE} ${VM_DISK_IMAGE_SIZE}
  fi
fi
[ -f "$KVM_IMAGE" ] || { echo "VM_DISK_IMAGE not found: ${KVM_IMAGE}"; exit 1; }
FLAGS_DISK_IMAGE="-drive file=${KVM_IMAGE},if=none,id=drive-disk0,format=qcow2 \
  -device virtio-blk-pci,scsi=off,bus=pci.0,addr=0x6,drive=drive-disk0,id=virtio-disk0,index=1"
echo "parameter: ${FLAGS_DISK_IMAGE}"

echo "[network]"

function cidr2mask() {
  local i mask=""
  local full_octets=$(($1/8))
  local partial_octet=$(($1%8))

  for ((i=0;i<4;i+=1)); do
    if [ $i -lt $full_octets ]; then
      mask+=255
    elif [ $i -eq $full_octets ]; then
      mask+=$((256 - 2**(8-$partial_octet)))
    else
      mask+=0
    fi
    test $i -lt 3 && mask+=.
  done

  echo $mask
}

function atoi {
  IP=$1; IPNUM=0
  for (( i=0 ; i<4 ; ++i )); do
    ((IPNUM+=${IP%%.*}*$((256**$((3-${i}))))))
    IP=${IP#*.}
  done
  echo $IPNUM
}

function itoa {
  echo -n $(($(($(($((${1}/256))/256))/256))%256)).
  echo -n $(($(($((${1}/256))/256))%256)).
  echo -n $(($((${1}/256))%256)).
  echo $((${1}%256))
}

# If we have a NETWORK_BRIDGE_IF set, add it to /etc/qemu/bridge.conf
if [ -z "$NETWORK" ] || [ "$NETWORK" == "bridge" ]; then
  IFACE=eth0
  BRIDGE_IFACE=br0
  MAC=`ip addr show $IFACE | grep ether | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*\$//g' | cut -f2 -d ' '`
  IP=`ip addr show dev $IFACE | grep "inet " | awk '{print $2}' | cut -f1 -d/`
  CIDR=`ip addr show dev $IFACE | grep "inet " | awk '{print $2}' | cut -f2 -d/`
  NETMASK=`cidr2mask $CIDR`
  GATEWAY=`ip route get 8.8.8.8 | grep via | cut -f3 -d ' '`
  NAMESERVER=( `grep nameserver /etc/resolv.conf | cut -f2 -d ' '` )
  NAMESERVERS=`echo ${NAMESERVER[*]} | sed "s/ /,/"`
  dnsmasq --user=root \
    --dhcp-range=$IP,$IP \
    --dhcp-host=$MAC,$HOSTNAME,$IP,infinite \
    --dhcp-option=option:router,$GATEWAY \
    --dhcp-option=option:netmask,$NETMASK \
    --dhcp-option=option:dns-server,$NAMESERVERS
  hexchars="0123456789ABCDEF"
  end=$( for i in {1..8} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/:\1/g' )
  NEWMAC=`echo 06:FE$end`
  let "NEWCIDR=$CIDR-1"
  i=`atoi $IP`
  let "i=$i^(1<<$CIDR)"
  NEWIP=`itoa i`
  ip link set dev $IFACE down
  ip link set $IFACE address $NEWMAC
  ip addr del $IP/$CIDR dev $IFACE
  brctl addbr $BRIDGE_IFACE
  brctl addif $BRIDGE_IFACE $IFACE
  ip link set dev $IFACE up
  ip link set dev $BRIDGE_IFACE up
  ip addr add $NEWIP/$NEWCIDR dev $BRIDGE_IFACE
  if [[ $? -ne 0 ]]; then
    echo "Failed to bring up network bridge"
    exit 4
  fi
  echo allow $BRIDGE_IFACE >  /etc/qemu/bridge.conf
  FLAGS_NETWORK="-netdev bridge,br=${BRIDGE_IFACE},id=net0 -device virtio-net-pci,netdev=net0,mac=${MAC}"
elif [ "$NETWORK" == "tap" ]; then
  echo "allow $NETWORK_BRIDGE_IF" >/etc/qemu/bridge.conf

  # Make sure we have the tun device node
  if [ ! -e /dev/net/tun ]; then
     set +e
     mkdir -p /dev/net
     mknod /dev/net/tun c 10 $(grep '\<tun\>' /proc/misc | cut -f 1 -d' ')
     set -e
  fi

  FLAGS_NETWORK="-netdev bridge,br=${NETWORK_BRIDGE_IF},id=net0 -device virtio-net,netdev=net0"
else
  FLAGS_NETWORK="-netdev tap,id=net0,script=/var/qemu-ifup -device virtio-net,netdev=net0"
fi
echo "Using ${NETWORK}"
echo "parameter: ${FLAGS_NETWORK}"

echo "[Remote Access]"
if [ -d /data ]; then
  FLAGS_REMOTE_ACCESS="-vnc unix:/data/vnc.socket"
fi
echo "parameter: ${FLAGS_REMOTE_ACCESS}"

set -x
exec /usr/bin/kvm ${FLAGS_REMOTE_ACCESS} \
  -k en-us -m ${VM_RAM} -cpu qemu64 \
  ${FLAGS_DISK_IMAGE} \
  ${FLAGS_NETWORK} \
  ${FLAGS_ISO} \
  $KVM_ARGS

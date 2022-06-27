#!/bin/bash

prefix_to_netmask() {
    local value=$((0xffffffff ^ ((1 << (32 - $1)) - 1)))
    echo "$(((value >> 24) & 0xff)).$(((value >> 16) & 0xff)).$(((value >> 8) & 0xff)).$((value & 0xff))"
}

ip_netmask_to_defgateway() {
    local i1 i2 i3 i4 m1 m2 m3 m4
    IFS=. read -r i1 i2 i3 i4 <<<$1
    IFS=. read -r m1 m2 m3 m4 <<<$2
    printf "%d.%d.%d.%d\n" \
        "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$((((i4 & m4)) + 1))"
}

get_interface_info() {
    local dev0 dev1 ipaddr netmask defgateway

    local ipout=$(ip -br -f inet address show | grep UP)

    local dev status cidr
    local i=0
    while read -r dev status cidr; do
        if [ $i -eq 0 ]; then
            dev0="$dev"
        elif [ $i -eq 1 ]; then
            dev1="$dev"
            ipaddr="${cidr%/*}"
            netmask=$(prefix_to_netmask "${cidr#*/}")
            defgateway=$(ip_netmask_to_defgateway $ipaddr $netmask)
        fi
        i=$((i + 1))
    done <<<"$ipout"

    echo "$dev0 $dev1 $ipaddr $netmask $defgateway"
}

if (($# < 1)); then
    cp /run/network/interfaces.d/* /etc/network/interfaces.d

    sed -e "s|^#source-directory /run/network/interfaces.d|source-directory /run/network/interfaces.d|g" \
        /etc/network/interfaces >interfaces-tmp
    mv interfaces-tmp /etc/network/interfaces

    echo "Attach 2nd network interface (or Ctrl-C to quit):"
    printf "  waiting for interface .."
    while true; do
        read -r dev0 dev1 ipaddr netmask defgateway <<<$(get_interface_info)
        if [ ! -z "$dev1" ]; then
            printf "\n  found $dev1 $ipaddr\n"
            break
        fi
        sleep 1
        printf "."
    done

    cat >"/etc/network/interfaces.d/$dev1" <<EOF
auto $dev1 
allow-hotplug $dev1

#iface $dev1 inet dhcp
iface $dev1 inet static
address $ipaddr
netmask $netmask

up ip route add default via $defgateway dev $dev1 table 1000
up ip rule add oif $dev1 table 1000

iface $dev1 inet6 manual
  try_dhcp 1
EOF

    sed -e "s|^source-directory /run/network/interfaces.d|#source-directory /run/network/interfaces.d|g" \
        /etc/network/interfaces >interfaces-tmp
    mv interfaces-tmp /etc/network/interfaces
    echo "$dev1 setup complete. Reboot."

    exit 0
else
    echo "Setting up VXLAN: remote IP $1"
    read -r dev0 dev1 ipaddr netmask defgateway <<<$(get_interface_info)
    if [ -z "$dev1" ]; then
        echo "2nd interface not found."
    else
        cat >"/etc/vxlan" <<EOF
ip link add vxlan0 type vxlan id 100 local $ipaddr remote $1 dev $dev1 dstport 4789
ip link set vxlan0 up

tc qdisc add dev $dev0 ingress;:
tc filter add dev $dev0 parent ffff: protocol all u32 match u8 0 0 action mirred egress mirror dev vxlan0

tc qdisc add dev $dev0 handle 1: root prio;:
tc filter add dev $dev0 parent 1: protocol all u32 match u8 0 0 action mirred egress mirror dev vxlan0

ip rule add oif vxlan0 table 1000
EOF
        printf "#!/bin/bash\n/etc/vxlan\n" >/etc/rc.local
        chmod 700 /etc/rc.local
        chmod 700 /etc/vxlan
        echo "VXLAN setup complete. Reboot."
    fi

    exit 0
fi

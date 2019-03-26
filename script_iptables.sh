#!/bin/sh
### BEGIN INIT INFO
# Provides:          cluster_passerelle
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start daemon at boot time
# Description:       Enable service provided by daemon.
### END INIT INFO

PATH=/usr/sbin:/sbin:/bin:/usr/bin

# declaring interfaces
outif="ens5" # the ethernet card connected to the interwebz
lanif="enp1s0" # the one connected to the lan

# some machines inside our network (optional)
#T1="192.168.50.101"
#T2="192.168.50.102"

# delete all existing rules.
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X

# Special port forwardings (both optional)
# This line would allow us to connect to the VNC service of an internal machine from outside the LAN
# We would connect to gateways_public_ip:9702 to reach our target
# iptables -t nat -A PREROUTING -p tcp --dport 8222 -j DNAT --to $T1:22
# Example of internal routing, using gateways_lan_ip:9705 would reach port 80, but couldn't be reached from outside
# could return useful, for instance, in case of particular VPN setups etc.
#iptables -t nat -A PREROUTING -p tcp -i $lanif --dport 9705 -j DNAT --to $printer:80

# Always accept loopback traffic
iptables -A INPUT -i lo -j ACCEPT

# Allow established connections, and those not coming from the outside
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
#iptables -A INPUT -m state --state NEW  -i ! $outif -j ACCEPT
# Using intrapositioned negation (`--option ! this`) is deprecated in favor of extrapositioned (`! --option this`)
iptables -A INPUT -m state --state NEW ! -i $outif -j ACCEPT
iptables -A FORWARD -i $outif -o $lanif -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow outgoing connections from the LAN side
iptables -A FORWARD -i $lanif -o $outif -j ACCEPT

# Masquerading
iptables -t nat -A POSTROUTING -o $lanif -j MASQUERADE
iptables -t nat -A POSTROUTING -o $outif -j MASQUERADE

# Don't forward from the outside to the inside
iptables -A FORWARD -i $outif -o $outif -j REJECT

# Ouvrir tous les ports du réseau privé (réseau de confiance)
#iptables -A INPUT -i $lanif -p TCP --dport * -m state --state NEW -j ACCEPT
iptables -A INPUT -m state --state NEW -i $lanif -j ACCEPT
# Enable routing.
# echo 1 > /proc/sys/net/ipv4/ip_forward

# Restart the dhcp service 
service isc-dhcp-server restart

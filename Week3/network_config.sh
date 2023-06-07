#!/bin/bash

#Select second interface; static?
interface=$(ip -4 -o address show scope global | awk ' NR==2 {print $2}')

static_ip="10.0.10.222"
netmask="255.255.255.0"
hostname=$(hostname)

#Network commands
nmcli connection add con-name $interface type ethernet ifname $interface ipv4.method manual ipv4.address $static_ip $netmask 

#Add to end of /etc/hosts
echo "$static_ip       $hostname" |sudo tee -a /etc/hosts

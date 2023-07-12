#!/bin/bash

new_host_name='autosrv'

static_ip="192.168.16.21/24"
gateway_ip="192.168.16.1"
dns_ip="192.168.16.1"

# Ensure script has appropriate permissions
if [ $USER != "root" ]; then
        echo "Please re-run script with sudo or root - exiting"
        exit 1
fi

# If hostname is not set to the new name, change it
if [ "$(hostname)" != "$new_host_name" ]; then
	echo "Changing hostname to $new_host_name!"
	hostnamectl set-hostname "$new_host_name"
else
	echo "Hostname already set to $new_host_name!"
fi

# Check if nmcli installed
nmcli -h > /dev/null 2>&1

# If nmcli is not installed, the error code will be non-zero
if [ $? -ne 0 ]; then
        echo "Unable to modify networking information; check if nmcli is installed."
        exit 1
fi

# Get the name of the last network interface; this configuration uses the first interface as DHCP, the final as static
interface_name=$(nmcli device status | grep -v "loopback" | awk '{print $1}' | tail -n1)

if [ -n "$interface_name" ]; then
    echo "Modifying Interface: $interface_name"
else
    echo "Failed to get network interface name; exiting"
    exit 1
fi

# If the current state of the connection is not active, add the connection
if [ $(nmcli device | grep $interface_name | awk '{print $3}') != 'connected' ]; then
	nmcli connection add con-name $interface_name ifname $interface_name type ethernet
fi

# Take interface down to modify it
echo "Placing $interface_name in an offline state to perform configuration"
nmcli con down $interface_name > /dev/null 2>&1

# Modify the connection to change it to the previously defined IP address and gateway
nmcli con mod $interface_name ipv4.method manual ipv4.addresses $static_ip ipv4.gateway $gateway_ip

# Change the DNS server IP address, as well as the search domains
nmcli con mod $interface_name ipv4.dns $dns_ip
nmcli con mod $interface_name ipv4.dns-search "home.arpa localdomain"

# Bring connection up after modifying
nmcli con up $interface_name > /dev/null 2>&1

if [ $? -eq 0 ]; then
        echo "$interface_name is now in an online state"
        exit 1
fi


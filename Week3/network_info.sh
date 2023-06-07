#!/bin/bash

#Show LAN interfaces
echo -e "--------- LAN Interfaces -------------\n"
ip -4 -o address show scope global |
awk '{print "Interface:", $2, $4}'

echo -e "\n-------- Network Information --------\n"
#Hostname associated w/ LAN
echo "Hostname: $(getent hosts $(hostname -I | cut -d ' ' -f1) | cut -d ' ' -f2)"

echo "Default Gateway: $(ip route show default | cut -d ' ' -f3)"
echo "Public IP Address: $(curl -s icanhazip.com)"

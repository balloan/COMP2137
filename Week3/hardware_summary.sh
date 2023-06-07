#!/bin/bash

echo " ------------ Hardware Details -----------"

# Processor Info
sudo inxi | head -1

#Memory Size Info
echo "System Memory: $(free -h | awk 'NR==2 {print $2}')"

#Network Interfaces
echo Network Interfaces:  $(ip -o link show | 
awk -F': ' '{printf "%s%s",sep,$2; sep=","} END{print ""}')

# Disk Information
echo "Disk Information:"
sudo lshw -c disk | grep -A6 '*-disk' | grep 'disk\|product\|description\|logical'

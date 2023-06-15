#!/bin/bash


#Get Date
current_date=$(date)

#Get OS information from /etc/os-release
source /etc/os-release

#Get uptime and hostname
uptime=$(uptime -p)
name_of_host=$(hostname)

#Gather CPU model, current, and max speed
cpu_model=$(sudo lscpu | grep -i 'model name' | cut -d: -f2 | xargs)
cpu_info=$(sudo lshw -c cpu)

#Quotations to retain line break information from $cpu_info
current_speed=$(echo "$cpu_info" | grep size | awk -F: 'NR == 1 {print $2}')
max_speed=$(echo "$cpu_info" | grep capacity | awk -F: 'NR == 1 {print $2}')

#Gather total RAM capacity
ram_size=$(free -h | awk 'NR==2 {print $2}')

#Gather the product name of the disk
disk_model=$(sudo lshw -c disk | grep -A6 '*-disk' | grep product | cut -d: -f2 | xargs)

#Gather GPU model and make
gpu_info=$(sudo lshw -C display)

#Note; " " to prevent echo from placing $gpu_info on a single line
gpu_model=$(echo "$gpu_info" | grep product | cut -d: -f2 | xargs)
gpu_make=$(echo "$gpu_info" | grep vendor | cut -d: -f2 | xargs)

#Gather FQDN, hostname IP, default gateway and DNS server
fqdn=$(hostname --fqdn)
hostname_ip=$(getent hosts $name_of_host | cut -d ' ' -f1)
gateway_address=$(ip r | awk 'NR==1 {print $3}')
dns_server=$(nslookup localhost | grep Server | cut -d: -f2 | xargs)
ip_addresses=$(ip -4 -o address show scope global | awk '{printf "%s  ", $4}') 

#Get NIC name, model and vendor
interface_information=$(sudo lshw -c network | grep 'product\|vendor\|logical name')

# Gather current logged in users, process and load information
logged_in_users=$(who -q | awk 'NR==1' | tr ' ' ',')
process_count=$(ps -auxh | wc -l)
load_averages=$(uptime | awk -F 'load average: ' '{print $2}')

# Store information on size & mountpoint of local filesystems
disk_free_info=$(echo 'Size Mountpoint'; df -lh | grep '^/dev/' | awk '{print $4, $6}')

# Gather RAM statistics
total_ram=$(free -h | awk 'NR==2 {print $2}')
used_ram=$(free -h | awk 'NR==2 {print $3}')
available_ram=$(free -h | awk 'NR==2 {print $4}')

#Gather listening port information. Format into a comma separated list
listening_ports=$(ss -tuln -4 | grep LISTEN | cut -d: -f2 | cut -d ' ' -f1 |  tr '\n' ', ')

#Store firewall status information; also shows rules if enabled & configured
ufw_info="$(sudo ufw status)"


cat <<EOF

System Report generated by $USER at $current_date

System Information
-------------------------
Hostname: $name_of_host
OS: $PRETTY_NAME
Uptime: $uptime

Hardware Information
-------------------------
CPU: $cpu_model
Speed: Current $current_speed, Maximum $max_speed
Total RAM: $ram_size
Disk: $disk_model
Video: $gpu_make $gpu_model

Network Information
-------------------------
FQDN: $fqdn
Host Address: $hostname_ip
Gateway IP: $gateway_address
DNS Server: $dns_server

Interface Information:
$interface_information

IP Address(es): $ip_addresses

System Status
-------------------------
Users Logged In: $logged_in_users

Disk Space: 
$disk_free_info

Process Count: $process_count
Load Averages: $load_averages
Memory Allocation: Total RAM = $total_ram, Used RAM = $used_ram, Free RAM = $available_ram

Listening Network Ports: $listening_ports
Firewall Information: $ufw_info
EOF


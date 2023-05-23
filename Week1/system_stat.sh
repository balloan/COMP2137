#!/bin/bash
idle_cpu=$(top -bn 1 | grep "Cpu(s)" | cut -d ',' -f 4 | cut -d ' ' -f 2)
free_mem=$(free -h | awk 'NR==2 {print $NF}')

#Only gives output from one disk currently
disk_free=$(df -h --type=ext4 --type=ext3 | awk 'NR==2 {print $4}')

echo "CPU Usage: $(echo "100 - $idle_cpu" | bc)"
echo "Free RAM: $free_mem"
echo "Disk free: $disk_free"

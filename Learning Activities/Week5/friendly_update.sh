#!/bin/bash

log_file="/tmp/friendly_update_log.txt"

# Writes command used to log file. Outputs STDOUT and STDERR to log
execute_and_log() {
        echo "Command: $1" >> $log_file
        eval "$1" >> $log_file 2>&1
}

# Ensure script has appropriate permissions
if [ $USER != "root" ]; then
        echo "Please re-run script with sudo or root - exiting"
        exit 1
fi

# Use the execute & log function on apt update
execute_and_log "apt update"

# Check error status of update; exit if failed
if [ $? -ne 0 ]; then
        echo "Update failed; exiting"
        exit 1
fi

package_info=$(tail -n1 /tmp/friendly_update_log.txt | cut -d '.' -f1)

echo $package_info

# Prompt user to continue with update; exit if no, proceed if yes
while read -p "Do you wish to proceed with the update? (y/n) : " to_update; do
        if [ "$to_update" = "n" ] || [ "$to_update" = "N" ]; then
                echo "Exiting script"
                exit 1
        elif [ "$to_update" = "y" ] || [ "$to_update" = "Y" ]; then
                break
        else
                echo "Invalid input"
        fi
done

root_space=$(df -h / | awk 'NR==2 {print $4}')

echo "There is currently $root_space free in the root filesystem - beginning update."

execute_and_log "apt upgrade -y"

if [ $? -ne 0 ]; then
        echo "Upgrade failed; exiting"
        exit 1
fi

root_space=$(df -h / | awk 'NR==2 {print $4}')
echo "Update successful! There is currently $root_space free in the root filesystem after the update"


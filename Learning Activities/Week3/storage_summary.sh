#!/bin/bash

echo -e "-------- Storage Summary ----------\n"

echo -e "-- Local Mounted Filesystem Information -- \n"
df -h

echo -e "\n-- Mounted Network Filesystems --\n"
mount -t nfs,smbfs,cifs

echo -e "\n-- Home Directory File System Information --\n"
df -h ~

echo -e "\n-- Home Directory Information--"
echo "Space used: $(du ~ -sh | cut -f1)"
echo "Number of files: $(ls ~ | wc -l)"

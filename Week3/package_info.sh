#!/bin/bash

echo "SSH Information: 
$(dpkg -l | grep 'openssh' | awk '{print $2, $3}')"

dpkg -S /bin/bash
dpkg -L openssh-server
dpkg -L openssh-client

echo "Snap Information"
snap list


#!/bin/bash

exit_on_failure () {
if [ $? -ne 0 ]; then
	echo "$1 failed. Exiting script"
        exit 1
fi
}

### MACHINE ONE CONFIG ###

# Check hostname
target1_host=$(ssh -o StrictHostKeyChecking=no remoteadmin@target1-mgmt hostname)
exit_on_failure "SSH into target1"

# Change hostname if necessary
if [ "$target1_host" != "loghost" ]; then
	echo "Changing server name to loghost"
	ssh remoteadmin@target1-mgmt hostnamectl "set-hostname loghost"
 	exit_on_failure "Changing server name"
fi

# Find netplan file name
target1_netplan=$(ssh remoteadmin@target1-mgmt "find /etc/netplan -type f")
exit_on_failure "Finding netplan file"

# Exit if multiple netplan files found; unexpected configuration
if [ $(echo "$target1_netplan" | wc -l) -gt 1 ]; then
	echo "Multiple netplan files found; exiting"
	exit 1
fi

# Edit netplan file
ssh remoteadmin@target1-mgmt "cat > $target1_netplan <<EOF
network:
    version: 2
    ethernets:
        eth0:
            addresses: [192.168.16.3/24]
            routes:
              - to: default
                via: 192.168.16.2
            nameservers:
                addresses: [192.168.16.2]
                search: [home.arpa, localdomain]
        eth1:
            addresses: [172.16.1.10/24]
EOF"
exit_on_failure "Modifying netplan file"

# Apply netplan changes
ssh remoteadmin@target1-mgmt "netplan apply > /dev/null 2>&1"
exit_on_failure "Netplan apply on target1"

#  Add a machine named webhost to the /etc/hosts file with host 4 on the lan
ssh remoteadmin@target1-mgmt "echo '192.168.16.4 webhost' >> /etc/hosts"
exit_on_failure "Modifying /etc/hosts on target1"


# UFW Settings
ssh remoteadmin@target1-mgmt "apt-get update > /dev/null 2>&1"
exit_on_failure "Updating apt"
ssh remoteadmin@target1-mgmt "apt-get install ufw -y > /dev/null 2>&1"
exit_on_failure "Installing UFW"
ssh remoteadmin@target1-mgmt  "ufw allow from 172.16.1.0/24 to any port 514 proto udp > /dev/null 2>&1"
exit_on_failure "Modifying UFW rules"

# Config Syslog

# Executing those sed commands through ssh without the EOF was messy; too many escape characters needed

ssh remoteadmin@target1-mgmt /bin/bash << EOF
sed -i 's/^#module(load=\"imudp\")/module(load=\"imudp\")/' /etc/rsyslog.conf
sed -i 's/^#\(input(type="imudp" port="514")\)/\1/' /etc/rsyslog.conf
EOF
exit_on_failure "Modifying /etc/rsyslog.conf on target1"

# Restart the rsyslog service
ssh remoteadmin@target1-mgmt systemctl restart rsyslog
exit_on_failure "Restarting rsyslog service on target1"

echo "Successfully modified Target1's configuration"

### MACHINE TWO CONFIG ###

# Check hostname
target2_host=$(ssh -o StrictHostKeyChecking=no remoteadmin@target2-mgmt hostname)
exit_on_failure "SSH into target2"

# Change hostname if necessary
if [ "$target2_host" != "webhost" ]; then
	echo "Changing server name to webhost"
	ssh remoteadmin@target2-mgmt hostnamectl "set-hostname webhost"
 	exit_on_failure "Changing target2 hostname"
fi

# Find netplan file to change it
target2_netplan=$(ssh remoteadmin@target2-mgmt "find /etc/netplan -type f")
exit_on_failure "Finding /etc/netplan file on target2"

# Exit if multiple netplan files found; unexpected configuration
if [ $(echo "$target2_netplan" | wc -l) -gt 1 ]; then
	echo "Multiple netplan files found; exiting"
	exit 1
fi

# Edit netplan file
ssh remoteadmin@target2-mgmt "cat > $target2_netplan <<EOF
network:
    version: 2
    ethernets:
        eth0:
            addresses: [192.168.16.4/24]
            routes:
              - to: default
                via: 192.168.16.2
            nameservers:
                addresses: [192.168.16.2]
                search: [home.arpa, localdomain]
        eth1:
            addresses: [172.16.1.11/24]
EOF"
exit_on_failure "Modifying netplan file on target2"

# Apply netplan changes
ssh remoteadmin@target2-mgmt "netplan apply > /dev/null 2>&1"
exit_on_failure "Applying netplan changes on target2"


# Add loghost to /etc/hosts
ssh remoteadmin@target2-mgmt 'echo "192.168.16.3 loghost" >> /etc/hosts'
exit_on_failure "Modifying /etc/hosts on target2"

# UFW Settings
ssh remoteadmin@target2-mgmt "apt-get update > /dev/null 2>&1"
exit_on_failure "Updating apt"
ssh remoteadmin@target2-mgmt "apt-get install ufw -y > /dev/null 2>&1"
exit_on_failure "Installing UFW on target2"
ssh remoteadmin@target2-mgmt "ufw allow 80/tcp > /dev/null 2>&1"
exit_on_failure "Modifying UFW rules on target2"

# Apache Install
ssh remoteadmin@target2-mgmt "apt-get install apache2 -y > /dev/null 2>&1"
exit_on_failure "Installing Apache on target2"

# Configure rsyslog on webhost to send logs to loghost
ssh remoteadmin@target2-mgmt 'echo "*.* @loghost" >> /etc/rsyslog.conf'
exit_on_failure "Modifying /etc/rsyslog.conf on target2"
ssh remoteadmin@target2-mgmt  'systemctl restart rsyslog'
exit_on_failure "Restarting rsyslog on target2"

echo "Successfully modified Target1's configuration"

# Edit host machine /etc/hosts file
sudo sed -i 's/192\.168\.16\.10 target1/192.168.16.3 loghost/' /etc/hosts
exit_on_failure "Modifying /etc/hosts on local machine"
sudo sed -i 's/192\.168\.16\.11 target2/192.168.16.4 webhost/' /etc/hosts

# Search for the default Apache page; verify that site is up
wget -qO- http://webhost | grep "It works" > /dev/null
exit_on_failure "Loading page from webhost"

# Check to see how many lines containing webhost are in loghost's syslog
lines=$(ssh remoteadmin@loghost "grep webhost /var/log/syslog | wc -l")

if [ "$lines" -eq "0" ]; then
	echo "Unable to retrieve webhost logfiles; exiting"
	exit 1
fi

echo "Configuration update succeeded!"



#!/bin/bash

# Update prior to installing software
apt-get -y update >/dev/null 2>&1

# Check SSH server status; if not installed, it will give a non zero 
systemctl status sshd >/dev/null 2>&1

if [ $? -ne 0 ]; then
        echo "SSH server is not installed; installing"
        apt-get -y install openssh-server >/dev/null 2>&1
        echo "OpenSSH Server successfully installed"
fi

# Disable Password Authentication; -i allows it to write to file
sudo sed -i 's/^#*\s*PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config

sudo sed -i 's/^#*\s*PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config


# Restart SSH Server to apply changes
systemctl restart sshd


# Check if Apache is installed; if not installed, if not, install it
systemctl status sshd >/dev/null 2>&1

if [ $? -ne 0 ]; then
        echo "Apache is not installed; installing"
        apt-get install apache2 -y -q && echo "Apache web server successfully installed"
fi

#apache2 web server listening for http on port 80 and https on port 443 -> /etc/apache2/ports.conf








# Reset Firewall configuration to default
ufw reset

# Deny inbound by default, allow outbound
ufw default deny incoming
ufw default allow outgoing

# Enable firewall, allow specified services through
ufw enable
ufw allow 22,80,443,3128/tcp

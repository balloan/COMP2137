#!/bin/bash

users=("aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda" "dennis")

for user in "${users[@]}"; do
	#User w/ home directory + bash shell
	useradd -m  -s /bin/bash $user

# Run keygen as the user, output to the user home directory. -N for no password on the key
	sudo -u $user ssh-keygen -t rsa -f /home/$user/.ssh/id_rsa -N ""
	sudo -u aubrey ssh-keygen -t ed25519 -f /home/aubrey/.ssh/id_ed25519 -N ""

# Add to public key file
	cat /home/$user/.ssh/id_rsa.pub >> /home/$user/.ssh/authorized_keys
	cat /home/$user/.ssh/id_ed25519.pub >> /home/$user/.ssh/authorized_keys
done

# Add dennis to sudo group
usermod -aG sudo dennis

# Add key to authorized for dennis
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI" >> >> /home/dennis/.ssh/authorized_keys

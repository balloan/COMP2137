#!/bin/bash

exit_on_failure () {
if [ $? -ne 0 ]; then
	echo "$1 failed. Exiting script"
        exit 1
fi
}

old_host_name=$(hostname)
new_host_name='autosrv'

static_ip="192.168.16.21"
gateway_ip="192.168.16.1"
dns_ip="192.168.16.1"

# Ensure script has appropriate permissions
if [ "$UID" -ne "0" ]; then
        echo "Please re-run script with sudo or root - exiting"
        exit 1
fi

echo -e "System configuration will now begin. \n"

### HOSTNAME CONFIGURATION ###

echo -e "### HOSTNAME CONFIGURATION ### \n"

# If hostname is not set to the new name, change it
if [ "$old_host_name" != "$new_host_name" ]; then
	echo "Changing hostname to $new_host_name!"
	hostnamectl set-hostname "$new_host_name"
 	
	# Change all instances of old host name to the new name in /etc/hosts
	sed -i "s/$old_host_name/$new_host_name/g" /etc/hosts || { echo "Failed to update /etc/hosts file"; exit 1; }
	echo "Hostname information successfully applied."
else
	echo "Hostname already set to $new_host_name!"
fi

### NETWORK CONFIGURATION ###

echo -e "\n### NETWORK CONFIGURATION ### \n"

# Get the interface that is currently used for default route
default_interface=$(ip route | grep default | awk '{print $5}')

# Get the other interface; this one will be modified for a static configuration
interface_name=$(ip -o link show | grep -v 'lo' | grep -v "$default_interface" | awk -F': ' '{print $2}')

# Confirm that a second network interface was found
if [ -z "$interface_name" ]; then 
	echo "Unable to find the second network interface to modify; exiting script"
	exit 1
fi

echo "Modifying interface: $interface_name"

# Do not edit the netplan file if it already exists
if [[ -f /etc/netplan/01-"$interface_name".yaml ]]; then
	echo "Netplan file already exists for $interface_name; skipping configuration"
else

#Create the netplan file for the interface
cat > /etc/netplan/01-"$interface_name".yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface_name:
      addresses: [$static_ip/24]
      routes: 
        - to: 0.0.0.0
          via: $gateway_ip
      nameservers:
        addresses: [$dns_ip]
        search: [home.arpa, localdomain]
EOF
echo "Modified netplan file for $interface_name"
fi


netplan apply > /dev/null 2>&1 && echo "Netplan changes successfully applied"
exit_on_failure "Netplan apply"

# Get the IP address after applying changes; loop due to delay after netplan applying
for ((count = 0; count < 15; count++)); do
    new_ip=$(ip route | grep -v "via" | grep -v "$default_interface" | awk '{print $9}')
    if [ -n "$new_ip" ]; then
        break
    fi
    sleep 1
done

# Confirm the new ip is set to configured value
if [ "$new_ip" != "$static_ip" ]; then
        echo "IP configuration unsuccessful; exiting"
        echo "$new_ip did not equal $static_ip"
        exit 1
else
	echo "IP configuration was successful."
fi

### SOFTWARE CONFIGURATION ### 

echo -e "\n### SOFTWARE CONFIGURATION ### \n"

apt update > /dev/null 2>&1
packages=("openssh-server" "apache2" "squid" "ufw")

# Check if packages are installed
for package in "${packages[@]}"; do
	dpkg -s "$package" > /dev/null 2>&1
	if [ $? -ne 0 ]; then
 		# If package is not installed, install it
		echo "Installing package $package"
  		apt install -y $package > /dev/null 2>&1 && echo "$package installed successfully"
    		exit_on_failure "Installing $package"
    	fi
done

echo "All required packages are installed."

### SSH CONFIG ### 

# Disable Password Authentication
sed -i 's/^#*\s*PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
exit_on_failure "Modifying sshd_config"

# Enable Public Key Authentication
sed -i 's/^#*\s*PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
exit_on_failure "Modifying sshd_config"

# Uncomment the Authorized Keys file
sed -i 's/^#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config
exit_on_failure "Modifying sshd_config"

# Restart SSH Server to apply changes
systemctl restart sshd && echo "SSH successfully configured."
exit_on_failure "Restarting SSH service"

### APACHE CONFIG ###

a2enmod ssl  > /dev/null 2>&1
exit_on_failure "Enabling SSL for Apache"

systemctl restart apache2  > /dev/null 2>&1 && echo "Apache successfully configured"
exit_on_failure "Restarting Apache service"

### SQUID CONFIG ###

# Uncomment default port for Squid
sudo sed -i 's/#http_port 3128/http_port 3128/' /etc/squid/squid.conf
exit_on_failure "Editing Squid configuration"

systemctl restart squid  > /dev/null 2>&1 && echo "Squid successfully configured."
exit_on_failure "Restarting Squid service"


### FIREWALL CONFIG ### 

echo "Configuring firewall settings."

# SSH, HTTP, HTTPS, Squid
ports=("22" "80" "443" "3128")

for port in "${ports[@]}"; do
	# Add port to UFW rules
	ufw allow $port/tcp > /dev/null 2>&1
 	exit_on_failure "Allowing $port through UFW"

   	# Confirm that system is listening on the specified port
	ss -tunlp | cut -d: -f2 | grep $port > /dev/null 2>&1
 
 	if [ $? -ne 0 ]; then
        	echo "System not listening on $port. Unexpected; exiting script"; exit 1
    	fi
done

ufw enable > /dev/null 2>&1 && echo "UFW configured and enabled"
exit_on_failure "Enabling UFW"

### ACCOUNT CONFIGURATION ###

echo -e "\n### USER ACCOUNT CONFIGURATION ### \n"

users=("aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda" "dennis")

for user in "${users[@]}"; do
	# Check if user exists
	getent passwd $user > /dev/null 2>&1 

 	# Skip adding user if they already exist
	if [ $? -eq 0 ]; then
	        echo "$user already exists; skipping $user creation"
	else
 	#Add User w/ home directory and bash shell
 		useradd -m  -s /bin/bash $user 2>/dev/null
   		exit_on_failure "Adding user $user"
		echo "User $user was successfully created!"
	fi

 	# Check if user already has a key file
	if [[ -f /home/$user/.ssh/id_rsa ]]; then
		echo "RSA key already exists for $user"
	else
		# Create key pair for the user and add it to the authorized_keys file
		sudo -u $user ssh-keygen -q -t rsa -f /home/$user/.ssh/id_rsa -N "" > /dev/null
		exit_on_failure "Generating RSA key"
		cat /home/$user/.ssh/id_rsa.pub >> /home/$user/.ssh/authorized_keys
    	fi

	if [[ -f /home/$user/.ssh/id_ed25519 ]]; then
		echo "ed25519 key already exists for $user"
	else
	 	# Create key pair for the user and add it to the authorized_keys file
  		sudo -u $user ssh-keygen -t ed25519 -f /home/$user/.ssh/id_ed25519 -N "" > /dev/null
		exit_on_failure "Generating ed25519 key"
		cat /home/$user/.ssh/id_ed25519.pub >> /home/$user/.ssh/authorized_keys
	fi
	
	echo "$user SSH key configuration successful."
done

# Check if dennis belongs to sudo; if not, add to sudo group.
id dennis | grep sudo > /dev/null 2>&1 || ( usermod -aG sudo dennis > /dev/null 2>&1 && echo "dennis was added to sudo group" )
exit_on_failure "Adding dennis to sudo group"

# Add key to authorized_users for dennis

grep "AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI" /home/dennis/.ssh/authorized_keys > /dev/null 2>&1
if [ $? -eq 0 ]; then
	echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI" >> /home/dennis/.ssh/authorized_keys
	exit_on_failure "Adding additional private key for user dennis"
 	echo "Added additional key to authorized_keys for dennis"
fi

echo -e "\nConfiguration complete!"

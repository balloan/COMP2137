#!/bin/bash

test_command () {
if [ $? -eq 0 ]; then
        echo "$1 was successful"
else
	echo "$1 failed; exiting script"
	exit 1
fi
}

old_host_name=$(hostname)
new_host_name='autosrv'

static_ip="192.168.16.21"
gateway_ip="192.168.16.1"
dns_ip="192.168.16.1"

# Ensure script has appropriate permissions
if [ "$USER" != "root" ]; then
        echo "Please re-run script with sudo or root - exiting"
        exit 1
fi

echo -e "System configuration will now begin. \n"

### HOSTNAME CONFIGURATION ###

echo -e "### HOSTNAME CONFIGURATION ### \n"

# If hostname is not set to the new name, change it
if [ "$old_host_name" != "$new_host_name" ]; then
	echo "Changing hostname to $new_host_name!"
	hostnamectl set-hostname "$new_host_name" || { echo "Failed to update hostname"; exit 1; }
	
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

# Debugging
# echo "Default: $default_interface   to config: $interface_name"

# Confirm that a second network interface was found
if [ -z "$interface_name" ]; then 
	echo "Unable to find the second network interface to modify; exiting script"
	exit 1
fi

echo "Modifying interface: $interface_name"

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

test_command "Modifying netplan file"
netplan apply > /dev/null 2>&1
test_command "Applying netplan changes"

sleep 1

new_ip=$(ip route | grep -v "via" | grep -v "$default_interface" | awk '{print $9}')

# Debugging
# echo "Default interface is $default_interface"
# echo "new IP is: $new_ip"
# echo "static_ip is $static_ip"

if [ "$new_ip" != "$static_ip" ]; then
        echo "IP configuration unsuccessful; exiting"
        echo "$new_ip did not equal $static_ip"
        exit 1
else
	echo "IP configuration was successful."
fi

### SOFTWARE CONFIGURATION ### 

echo -e "\n###SOFTWARE CONFIGURATION ### \n"

packages=("openssh-server" "apache2" "squid" "ufw")
missing_packages=()

# Check if packages are installed; add uninstalled ones to an array
for package in "${packages[@]}"; do
	dpkg -s "$package" > /dev/null 2>&1
	if [ $? -ne -0 ]; then
        missing_packages+=("$package")
    fi
done

# Install missing packages
if [[ ${#missing_packages[@]} -gt 0 ]]; then
	apt update > /dev/null 2>&1
	echo "Installing package(s): ${missing_packages[@]}"
    apt install -y "${missing_packages[@]}" > /dev/null 2>&1 || { echo "Failed to install packages; exiting "; exit 1; }
fi

echo "Packages successfully installed."

### SSH CONFIG ### 

# Disable Password Authentication, enable pubkey authentication -i allows it to write to file
sed -i 's/^#*\s*PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config || { echo "Disabling password auth failed"; exit 1; }
sed -i 's/^#*\s*PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config || { echo "Enabling pub key auth failed"; exit 1; }
sed -i 's/^#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config || { echo "Setting Authorized Keys file failed"; exit 1; }

# Restart SSH Server to apply changes
systemctl restart sshd

# Confirm service restarted; provide output to user
test_command "Configuring SSH"

### APACHE CONFIG ###

a2enmod ssl  > /dev/null 2>&1
test_command "Enabling SSL for Apache"
systemctl restart apache2  > /dev/null 2>&1
test_command "Configuring Apache"

### SQUID CONFIG ###

# It listens to 3128 by default; if it's commented out for some reason this will uncoment it
sudo sed -i 's/#http_port 3128/http_port 3128/' /etc/squid/squid.conf || { echo "Changing Squid listening port failed"; exit 1; }

systemctl restart squid  > /dev/null 2>&1
test_command "Configuring Squid"


### FIREWALL CONFIG ### 

echo "Configuring firewall settings."

# Enable firewall, allow specified services through
ufw enable > /dev/null 2>&1 || { echo "Failed to enable firewall; exiting "; exit 1; }
ufw allow 22,80,443,3128/tcp  > /dev/null 2>&1 || { echo "Failed to edit firewall settings; exiting "; exit 1; }

echo "Firewall settings successfully modified."

### VERIFY LISTENING PORTS ###

ports=("22" "80" "443" "3128")

# Check each port individually in ss; the ports in the array ports should be available and listening
for port in "${ports[@]}"; do
	ss -tunlp | cut -d: -f2 | grep $port > /dev/null 2>&1
 	if [ $? -ne -0 ]; then
        echo "System not listening on $port. Unexpected; exiting script"; exit 1
    fi
done


### ACCOUNT CONFIGURATION ###

echo -e "\n### USER ACCOUNT CONFIGURATION ### \n"

users=("aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda" "dennis")

for user in "${users[@]}"; do
	#Add User w/ home directory + bash shell
	useradd -m  -s /bin/bash $user 2>/dev/null
	if [ $? -ne -0 ]; then
	        echo "$user already exists; skipping $user configuration"
	else
		echo "$user was successfully created!"
		# Run keygen as the user, output to the user home directory. -N for no password on the key
		sudo -u $user ssh-keygen -t rsa -f /home/$user/.ssh/id_rsa -N "" > /dev/null
		test_command "Generating RSA key"
		sudo -u $user ssh-keygen -t ed25519 -f /home/$user/.ssh/id_ed25519 -N "" > /dev/null
		test_command "Generating ed25519 key"

		# Add key to user's public key file
		cat /home/$user/.ssh/id_rsa.pub >> /home/$user/.ssh/authorized_keys
		cat /home/$user/.ssh/id_ed25519.pub >> /home/$user/.ssh/authorized_keys
		echo "$user has been successfully configured with SSH keys."
	fi
done

# Add dennis to sudo group
usermod -aG sudo dennis > /dev/null 2>&1
test_command "Adding dennis to sudo group"

# Add key to authorized for dennis
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI" >> /home/dennis/.ssh/authorized_keys

test_command "Adding additional private key for user dennis"

echo -e "\nConfiguration complete!"

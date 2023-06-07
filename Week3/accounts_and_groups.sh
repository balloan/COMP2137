#!/bin/bash

# Create groups; if they already exist command silently exits
groups=("brews" "trees" "cars" "staff" "admins" "dennis")

for group in "${groups[@]}"; do
	sudo groupadd $group -f
done

#Users in brews
brews=("coors" "stella" "michelob" "guiness")

#Create users with home directory + appropriate group. Set password to random one

for user in "${brews[@]}"; do
	#User w/ home directory
	sudo useradd -m $user --groups brews

	#Set a random password for the user
	password=$(dd if=/dev/random count=1 status=none|base64|dd bs=16 count=1 status=none)
	echo "$user:$password" | sudo chpasswd
done

#Users in trees
trees=("oak" "pine" "cherry" "willow" "maple" "walnut" "ash" "apple")

#Create users with home directory + appropriate group. Set password to random one

for user in "${trees[@]}"; do
	#User w/ home directory
	sudo useradd -m $user --groups trees

	#Set a random password for the user
	password=$(dd if=/dev/random count=1 status=none|base64|dd bs=16 count=1 status=none)
	echo "$user:$password" | sudo chpasswd
done

#Users in cars
cars=("chrysler" "toyota" "dodge" "chevrolet" "ford" "suzuki" "pontiac" "hyundai" "cadillac" "jaguar")

#Create users with home directory + appropriate group. Set password to random one
for user in "${cars[@]}"; do
	#User w/ home directory
	sudo useradd -m $user --groups cars

	#Set a random password for the user
	password=$(dd if=/dev/random count=1 status=none|base64|dd bs=16 count=1 status=none)
	echo "$user:$password" | sudo chpasswd
done

#Users in staff
staff=("bill" "tim" "marilyn" "kevin" "george")

#Create users with home directory + appropriate group. Set password to random one
for user in "${staff[@]}"; do
	#User w/ home directory
	sudo useradd -m $user --groups staff

	#Set a random password for the user
	password=$(dd if=/dev/random count=1 status=none|base64|dd bs=16 count=1 status=none)
	echo "$user:$password" | sudo chpasswd
done

#Users in admin
admins=("bob" "rob" "brian")

#Create users with home directory + appropriate group. Set password to random one
for user in "${admins[@]}"; do
	#User w/ home directory
	sudo useradd -m $user --groups staff

	#Set a random password for the user
	password=$(dd if=/dev/random count=1 status=none|base64|dd bs=16 count=1 status=none)
	echo "$user:$password" | sudo chpasswd
done


#Dennis creation
sudo useradd -m dennis -g dennis --groups brews,trees,cars,staff,admins,sudo

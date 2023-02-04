#!/bin/bash

#
# SYNOPSIS:
# Prep Linux for a Proxmox template
#
# DESCRIPTION:
# This script will take a Linux VM and prep it to be used as a template in Proxmox.
# 
# Uses apt package manager
#

# Updates
echo "Running updates..."
sudo apt update
sudo apt upgrade -y
sudo apt dist-upgrade -y

# Install packages
echo "Installing packages"
sudo apt install openssh-server qemu-guest-agent cloud-init

# Create service to recreate ssh host keys and set it to run on first boot
# Thanks to https://www.youtube.com/watch?v=E8VjZ62Ns6Y
echo "Deleting SSH Host keys and preping them to be created on first boot..."
file_content='
[Unit]
Description=Regenerate SSH host keys
Before=ssh.service
ConditionFileIsExecutable=/usr/bin/ssh-keygen
 
[Service]
Type=oneshot
ExecStartPre=-/bin/dd if=/dev/hwrng of=/dev/urandom count=1 bs=4096
ExecStartPre=-/bin/sh -c \"/bin/rm -f -v /etc/ssh/ssh_host_*_key*\"
ExecStart=/usr/bin/ssh-keygen -A -v
ExecStartPost=/bin/systemctl disable regenerate_ssh_host_keys
 
[Install]
WantedBy=multi-user.target
'
echo "$file_content" > regenerate_ssh_host_keys.service
sudo chown root:root regenerate_ssh_host_keys.service
sudo mv regenerate_ssh_host_keys.service /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl enable regenerate_ssh_host_keys.service
sudo rm -f /etc/ssh/ssh_host_*

# Remove machine-id and make symbolic link to machine-id
echo "Cleaning up machine-id..."
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id

# Clean the template
echo "Cleaning up apt..."
sudo apt clean
sudo apt autoremove

# Clear hostname
echo "Clearing hostname"
sudo truncate -s 0 /etc/hostname
sudo hostnamectl set-hostname localhost

# Run cloud-init clean
echo "Cleaning cloud-init"
sudo cloud-init clean

#cleanup /tmp directories
echo "Cleaning temp directories..."
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# Clean bash history
echo "Forgetting the past..."
cat /dev/null > ~/.bash_history
history -w
history -c

# Power down the VM
echo "Shutting down..."
sudo poweroff
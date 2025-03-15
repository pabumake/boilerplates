#!/bin/bash

# Update package lists
sudo apt update

# Install basic troubleshooting tools
sudo apt install -y nano iputils-ping dnsutils network-manager

# Disable and stop default networking services that might conflict
sudo systemctl disable --now systemd-networkd.service || true
sudo systemctl disable --now systemd-resolved.service || true

# Configure NetworkManager to handle DNS directly
sudo sed -i '/^\[main\]/a dns=default' /etc/NetworkManager/NetworkManager.conf

# Enable NetworkManager
sudo systemctl enable --now NetworkManager.service

# Configure system to use NetworkManager
sudo rm -f /etc/resolv.conf
sudo ln -sf /run/NetworkManager/resolv.conf /etc/resolv.conf

# Restart NetworkManager
sudo systemctl restart NetworkManager.service

# Inform user
cat << EOF

Troubleshooting tools installed:
 - nano (editor)
 - ping
 - dig/nslookup (dnsutils)
 - NetworkManager (nmtui for connection management)

You can now manage network connections using 'nmtui'. DNS is directly managed by NetworkManager.

EOF


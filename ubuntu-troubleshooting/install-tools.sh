#!/bin/bash

# Update package lists
sudo apt update

# Install basic troubleshooting tools
sudo apt install -y nano iputils-ping dnsutils network-manager

# Disable and stop default networking services that might conflict
sudo systemctl disable --now systemd-networkd.service || true
sudo systemctl disable --now systemd-resolved.service || true

# Enable NetworkManager
sudo systemctl enable --now NetworkManager.service

# Configure system to use NetworkManager
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

You can now manage network connections using 'nmtui'.

EOF

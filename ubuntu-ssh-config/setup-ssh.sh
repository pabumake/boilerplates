#!/bin/bash

# Variables
AUTHORIZED_KEYS_URL="https://raw.githubusercontent.com/pabumake/boilerplates/refs/heads/main/ubuntu-ssh-config/id_ed25519_sk.pub?token=GHSAT0AAAAAAC6GYWLWK5YVLVPF772SXRQ4Z6WAEZA"
SSH_CONFIG_URL="https://raw.githubusercontent.com/pabumake/boilerplates/main/ubuntu-ssh-config/50-ssh.conf"
SSHD_CONFIG_DIR="/etc/ssh/sshd_config.d"
AUTHORIZED_KEYS_FILE="$HOME/.ssh/authorized_keys"

# Ensure .ssh directory exists
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Download authorized_keys
curl -fsSL "$AUTHORIZED_KEYS_URL" -o "$AUTHORIZED_KEYS_FILE"
chmod 600 "$AUTHORIZED_KEYS_FILE"

# Clean sshd_config.d directory and set new config
sudo mkdir -p "$SSHD_CONFIG_DIR"
sudo rm -f "$SSHD_CONFIG_DIR"/*
sudo curl -fsSL "$SSH_CONFIG_URL" -o "$SSHD_CONFIG_DIR/50-ssh.conf"
sudo chmod 644 "$SSHD_CONFIG_DIR/50-ssh.conf"

# Restart SSH service
sudo systemctl restart ssh

# Done
echo "SSH configuration has been successfully applied."

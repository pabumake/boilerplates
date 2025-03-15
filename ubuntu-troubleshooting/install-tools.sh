#!/bin/bash

# Update package lists
sudo apt update

# Install basic troubleshooting tools
sudo apt install -y nano iputils-ping dnsutils network-manager

# Disable conflicting networking services
sudo systemctl disable --now systemd-networkd.service || true
sudo systemctl disable --now systemd-resolved.service || true

# Ensure NetworkManager manages DNS directly
sudo sed -i '/^\[main\]/a dns=default' /etc/NetworkManager/NetworkManager.conf

# Force NetworkManager to reload its config immediately
sudo systemctl enable --now NetworkManager
sudo systemctl restart NetworkManager
sleep 2  # Wait for NetworkManager to settle

# Fix resolv.conf link
sudo rm -f /etc/resolv.conf
sudo ln -sf /run/NetworkManager/resolv.conf /etc/resolv.conf

# Restart networking explicitly via NetworkManager (force reload connections)
nmcli networking off
sleep 2
nmcli networking on
sleep 2

# Reactivate all existing NetworkManager connections explicitly
for conn in $(nmcli -t -f NAME connection show); do
  nmcli connection down "$conn"
  sleep 1
  nmcli connection up "$conn"
done

# Final DNS Check (to confirm it's working)
echo "Testing DNS resolution..."
if nslookup heise.de >/dev/null; then
    DNS_STATUS="successful ✅"
else
    DNS_STATUS="failed ❌ (please reboot manually)"
fi

# Inform user
cat << EOF

Troubleshooting tools installed:
 - nano (editor)
 - ping
 - dig/nslookup (dnsutils)
 - NetworkManager (nmtui for connection management)

Network connections are now fully controlled by NetworkManager.

DNS resolution test was $DNS_STATUS

You can now manage connections using 'nmtui'.

EOF
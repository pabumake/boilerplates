# Ubuntu SSH Configuration

This directory contains scripts to quickly set up and configure SSH securely and efficiently on Ubuntu machines.

---

## Available Scripts

### 📄 `setup-ssh.sh`

- Configures SSH keys and applies a standardized SSH configuration from the repository.
- Downloads and applies your public key to the user's `authorized_keys`.
- Clears existing SSH configuration in `/etc/ssh/sshd_config.d/` and applies `50-ssh.conf`.

**Quick execution:**
```bash
curl -fsSL https://raw.githubusercontent.com/pabumake/boilerplates/main/ubuntu-ssh-config/setup-ssh.sh | bash
```

---

### 🛠️ `install-tools.sh`

- Installs essential troubleshooting utilities:
  - `nano` (text editor)
  - `ping` (network troubleshooting)
  - `dnsutils` (`dig` and `nslookup`)
  - `network-manager` (use `nmtui` for network configuration)

- Sets up `NetworkManager` as the primary connection manager.

**Quick execution:**
```bash
curl -fsSL https://raw.githubusercontent.com/pabumake/boilerplates/main/ubuntu-troubleshooting/install-tools.sh | bash
```

---

## Usage

Simply copy and execute the provided commands directly on your Ubuntu machine for a fast and reliable setup.

---

## License

MIT License © pabumake


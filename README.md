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

### 🐳 setup-2-node-swarm.sh

Note: It is recommendet to run this before you run the ubuntu-ssh-config, because we require password authentication to setup docker

- Purpose: Sets up a Docker Swarm cluster with two nodes:
- docker0 (Manager) with IP 192.168.1.10
- docker1 (Worker) with IP 192.168.1.11
  
Features:
- Installs Docker and Docker Compose on both nodes.
- Initializes the Swarm on the manager node and joins the worker node to the Swarm.

**Quick execution:**

On the Manager Node (docker0):
```bash
curl -fsSL https://raw.githubusercontent.com/pabumake/boilerplates/main/ubuntu-swarm/setup-2-node-swarm.sh | bash -s manager
```

On the Worker Node (docker1):
```bash
curl -fsSL https://raw.githubusercontent.com/pabumake/boilerplates/main/ubuntu-swarm/setup-2-node-swarm.sh | bash -s worker
```

Note: 
- Replace your_username with your actual username on both machines.
- Ensure that SSH key-based authentication is set up between the manager and worker nodes for passwordless SSH access.
- After running the scripts, verify the Swarm status on the manager node (docker0) by executing:
```bash
sudo docker node ls
````


---

## Usage

Simply copy and execute the provided commands directly on your Ubuntu machine for a fast and reliable setup.

---

## License

MIT License © pabumake


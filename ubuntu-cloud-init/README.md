# Usage

Once Ubuntu is installed, run the following on your new server:
```bash
curl -o cloud-init.yaml https://raw.githubusercontent.com/YOUR_GITHUB_REPO/main/cloud-init.yaml
sudo cloud-init init --file cloud-init.yaml
```

## 🚀 Boom! The system will now:
	1.	Download & apply all updates.
	2.	Configure SSH and passwordless sudo.
	3.	Set up Docker Swarm.
	4.	Clone your GitHub repo and run additional automation.
	5.	Reboot to apply everything.
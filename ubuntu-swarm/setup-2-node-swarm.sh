#!/bin/bash

# Variables, adjust accordingly
ROLE=$1
MANAGER_IP="192.168.1.10"
WORKER_IP="192.168.1.11"
USER="pbmk"
DOCKER_COMPOSE_VERSION="2.34.0"

# Function to install Docker
install_docker() {
  echo "Updating package index..."
  sudo apt-get update -y

  echo "Installing prerequisite packages..."
  sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

  echo "Adding Docker's GPG key..."
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

  echo "Adding Docker repository..."
  sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"

  echo "Updating package index again..."
  sudo apt-get update -y

  echo "Installing Docker CE..."
  sudo apt-get install -y docker-ce

  echo "Adding user to the docker group..."
  sudo usermod -aG docker $USER

  echo "Enabling and starting Docker service..."
  sudo systemctl enable docker
  sudo systemctl start docker
}

# Function to install Docker Compose
install_docker_compose() {
  echo "Downloading Docker Compose..."
  sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

  echo "Applying executable permissions to Docker Compose..."
  sudo chmod +x /usr/local/bin/docker-compose

  echo "Creating symbolic link to /usr/bin..."
  sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

  echo "Verifying Docker Compose installation..."
  docker-compose --version
}

# Function to initialize Docker Swarm
initialize_swarm() {
  echo "Initializing Docker Swarm on manager node..."
  sudo docker swarm init --advertise-addr $MANAGER_IP
}

# Function to join Docker Swarm as a worker
join_swarm() {
  echo "Retrieving join token from manager node..."
  JOIN_TOKEN=$(ssh $USER@$MANAGER_IP "sudo docker swarm join-token worker -q")

  echo "Joining Docker Swarm as worker node..."
  sudo docker swarm join --token $JOIN_TOKEN $MANAGER_IP:2377
}

# Main script execution
if [ "$ROLE" == "manager" ]; then
  install_docker
  install_docker_compose
  initialize_swarm
elif [ "$ROLE" == "worker" ]; then
  install_docker
  join_swarm
else
  echo "Invalid role specified. Use 'manager' or 'worker'."
  exit 1
fi
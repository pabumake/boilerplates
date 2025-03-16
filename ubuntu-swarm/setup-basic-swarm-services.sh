#!/bin/bash

# Function to re-execute the script with sudo
function elevate_privileges() {
    if [ "$EUID" -ne 0 ]; then
        echo "Re-running script with elevated privileges..."
        sudo "$0" "$@"
        exit $?
    fi
}

# Elevate privileges if not already running as root
elevate_privileges "$@"

# Prompt for the main domain
read -p "Enter your main domain (e.g., example.com): " MAIN_DOMAIN

# Prompt for the email address to be used with Let's Encrypt
read -p "Enter your email address for Let's Encrypt notifications: " EMAIL

# Variables
TRAEFIK_NETWORK="traefik-public"
TRAEFIK_VERSION="docker.io/library/traefik:latest"
PORTAINER_VERSION="portainer/portainer-ce:latest"
ACME_FILE="/mnt/data/traefik/acme.json"

# Set subdomains based on the main domain
TRAEFIK_SUBDOMAIN="traefik.${MAIN_DOMAIN}"
PORTAINER_SUBDOMAIN="portainer.${MAIN_DOMAIN}"

# Read Traefik dashboard credentials from environment variables or prompt the user
TRAEFIK_DASHBOARD_USER="${TRAEFIK_DASHBOARD_USER:-}"
TRAEFIK_DASHBOARD_PASSWORD="${TRAEFIK_DASHBOARD_PASSWORD:-}"

if [ -z "$TRAEFIK_DASHBOARD_USER" ]; then
  read -p "Enter Traefik dashboard username: " TRAEFIK_DASHBOARD_USER
fi

if [ -z "$TRAEFIK_DASHBOARD_PASSWORD" ]; then
  read -sp "Enter Traefik dashboard password: " TRAEFIK_DASHBOARD_PASSWORD
  echo
fi

# Initialize Docker Swarm (if not already initialized)
docker swarm init --advertise-addr "$(hostname -I | awk '{print $1}')" || true

# Create Traefik network
docker network create --driver=overlay "$TRAEFIK_NETWORK" || true

# Create necessary directories and files for Traefik
mkdir -p /mnt/data/traefik
touch "$ACME_FILE"
chmod 600 "$ACME_FILE"

# Generate htpasswd for Traefik dashboard authentication
TRAEFIK_DASHBOARD_PASSWORD_ENCRYPTED=$(openssl passwd -apr1 "$TRAEFIK_DASHBOARD_PASSWORD")

# Create Docker Compose file
cat << EOF > docker-compose.yml
services:
  traefik:
    image: "${TRAEFIK_VERSION}"
    command:
      - --log.level=INFO
      - --api.dashboard=true
      - --providers.docker.swarmMode=true
      - --providers.docker.network=${TRAEFIK_NETWORK}
      - --entryPoints.web.address=:80
      - --entryPoints.websecure.address=:443
      - --certificatesResolvers.le.acme.email=${EMAIL}
      - --certificatesResolvers.le.acme.storage=/letsencrypt/acme.json
      - --certificatesResolvers.le.acme.tlsChallenge=true
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "${ACME_FILE}:/letsencrypt/acme.json"
    networks:
      - ${TRAEFIK_NETWORK}
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.traefik.rule=Host(\`${TRAEFIK_SUBDOMAIN}\`)"
        - "traefik.http.routers.traefik.service=api@internal"
        - "traefik.http.routers.traefik.entrypoints=websecure"
        - "traefik.http.routers.traefik.tls.certresolver=le"
        - "traefik.http.middlewares.auth.basicauth.users=${TRAEFIK_DASHBOARD_USER}:${TRAEFIK_DASHBOARD_PASSWORD_ENCRYPTED}"
        - "traefik.http.routers.traefik.middlewares=auth"

  portainer:
    image: ${PORTAINER_VERSION}
    command: -H unix:///var/run/docker.sock
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - ${TRAEFIK_NETWORK}
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.portainer.rule=Host(\`${PORTAINER_SUBDOMAIN}\`)"
        - "traefik.http.routers.portainer.entrypoints=websecure"
        - "traefik.http.routers.portainer.tls.certresolver=le"

networks:
  ${TRAEFIK_NETWORK}:
    external: true

volumes:
  portainer_data:
EOF

# Deploy the stack
docker stack deploy -c docker-compose.yml traefik_portainer
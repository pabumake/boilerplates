#!/bin/bash

# Auto-elevate script permissions with sudo if necessary
[ "$EUID" -ne 0 ] && exec sudo -E bash "$0" "$@"

# Prompt for user inputs
read -p "Enter your main domain (e.g., example.com): " MAIN_DOMAIN
read -p "Enter your email address for Let's Encrypt notifications: " EMAIL

# Prompt for Traefik dashboard credentials if not set
if [ -z "$TRAEFIK_DASHBOARD_USER" ]; then
  read -p "Enter Traefik dashboard username: " TRAEFIK_DASHBOARD_USER
fi

if [ -z "$TRAEFIK_DASHBOARD_PASSWORD" ]; then
  read -sp "Enter Traefik dashboard password: " TRAEFIK_DASHBOARD_PASSWORD
  echo
fi

# Variables
TRAEFIK_NETWORK="traefik-public"
TRAEFIK_VERSION="docker.io/library/traefik:latest"
PORTAINER_VERSION="portainer/portainer-ce:latest"
ACME_FILE="/mnt/data/traefik/acme.json"
TRAEFIK_SUBDOMAIN="traefik.${MAIN_DOMAIN}"
PORTAINER_SUBDOMAIN="portainer.${MAIN_DOMAIN}"

# Initialize Docker Swarm (if needed)
docker swarm init --advertise-addr "$(hostname -I | awk '{print $1}')" || true

# Create Traefik network if not existing
docker network inspect $TRAEFIK_NETWORK >/dev/null 2>&1 || \
docker network create --driver=overlay --scope=swarm $TRAEFIK_NETWORK

# Prepare directories and files for Traefik
mkdir -p /mnt/data/traefik
touch "$ACME_FILE"
chmod 600 "$ACME_FILE"

# Encrypt Traefik dashboard password
TRAEFIK_DASHBOARD_PASSWORD_ENCRYPTED=$(openssl passwd -apr1 "$TRAEFIK_DASHBOARD_PASSWORD")

# Generate the docker-compose.yml with correctly expanded variables
cat << EOF > docker-compose.yml
version: "3.8"

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
        - "traefik.http.routers.traefik.rule=Host(\`traefik.${MAIN_DOMAIN}\`)"
        - "traefik.http.routers.traefik.entrypoints=websecure"
        - "traefik.http.routers.traefik.service=api@internal"
        - "traefik.http.routers.traefik.tls.certresolver=le"
        - "traefik.http.middlewares.auth.basicauth.users=${TRAEFIK_DASHBOARD_USER}:$(openssl passwd -apr1 ${TRAEFIK_DASHBOARD_PASSWORD})"
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
        - "traefik.http.routers.portainer.rule=Host(\`portainer.${MAIN_DOMAIN}\`)"
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

echo "Deployment complete! Access your services:"
echo "Traefik: https://traefik.${MAIN_DOMAIN}"
echo "Portainer: https://portainer.${MAIN_DOMAIN}"
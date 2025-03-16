#!/bin/bash

# Check for necessary environment variables
: "${MAIN_DOMAIN:?Please set MAIN_DOMAIN (e.g., example.com)}"
: "${EMAIL:?You must set EMAIL for Let's Encrypt notifications}" 
: "${TRAEFIK_DASHBOARD_USER:?You must set TRAEFIK_DASHBOARD_USER}" 
: "${TRAEFIK_DASHBOARD_PASSWORD:?You must set TRAEFIK_DASHBOARD_PASSWORD}"

# Ensure script runs with necessary privileges
[ "$EUID" -ne 0 ] && exec sudo -E bash "$0" "$@"

# Variables
TRAEFIK_NETWORK="traefik-public"
TRAEFIK_VERSION="traefik:v3.3"
PORTAINER_VERSION="portainer/portainer-ce:latest"
ACME_FILE="/mnt/data/traefik/acme.json"
TRAEFIK_SUBDOMAIN="traefik.${MAIN_DOMAIN}"
PORTAINER_SUBDOMAIN="portainer.${MAIN_DOMAIN}"

# Initialize Docker Swarm (if necessary)
docker swarm init --advertise-addr "$(hostname -I | awk '{print $1}')" || true

# Create Traefik network if not existing
docker network inspect $TRAEFIK_NETWORK >/dev/null 2>&1 || \
docker network create --driver=overlay --attachable $TRAEFIK_NETWORK

# Create necessary directories and files
mkdir -p /mnt/data/traefik
ACME_FILE="/mnt/data/traefik/acme.json"
touch "$ACME_FILE"
chmod 600 "$ACME_FILE"

# Generate Traefik dashboard credentials
TRAEFIK_DASHBOARD_PASSWORD_ENCRYPTED=$(openssl passwd -apr1 "$TRAEFIK_DASHBOARD_PASSWORD")

# Generate traefik.yml (static configuration for v3)
cat << EOF > traefik.yml
api:
  dashboard: true

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  swarm:
    endpoint: "unix:///var/run/docker.sock"

certificatesResolvers:
  le:
    acme:
      email: "${EMAIL}"
      storage: "/letsencrypt/acme.json"
      tlsChallenge: {}
EOF

# Generate docker-compose.yml
cat << EOF > docker-compose.yml
version: "3.8"

services:
  traefik:
    image: "traefik:v3.3"
    command:
      - --configFile=/traefik.yml
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "${ACME_FILE}:/letsencrypt/acme.json"
      - "./traefik.yml:/traefik.yml:ro"
    networks:
      - ${TRAEFIK_NETWORK}
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.traefik.rule=Host(\`${TRAEFIK_SUBDOMAIN}\`)"
        - "traefik.http.routers.traefik.entrypoints=websecure"
        - "traefik.http.routers.traefik.service=api@internal"
        - "traefik.http.routers.traefik.tls.certresolver=le"
        - "traefik.http.middlewares.auth.basicauth.users=${TRAEFIK_DASHBOARD_USER}:${TRAEFIK_DASHBOARD_PASSWORD_ENCRYPTED}"
        - "traefik.http.routers.traefik.middlewares=auth"

  portainer:
    image: portainer/portainer-ce:latest
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
        - "traefik.http.services.portainer.loadbalancer.server.port=9000"

networks:
  ${TRAEFIK_NETWORK}:
    external: true

volumes:
  portainer_data:
EOF

# Deploy stack
docker stack deploy -c docker-compose.yml traefik_portainer

# Output information
echo "Deployment complete! Access your services at:"
echo "Traefik Dashboard: https://${TRAEFIK_SUBDOMAIN}"
echo "Portainer Dashboard: https://${PORTAINER_SUBDOMAIN}"
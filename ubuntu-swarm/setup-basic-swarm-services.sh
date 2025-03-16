#!/bin/bash

# Prompt only if variables not set via environment
MAIN_DOMAIN="${MAIN_DOMAIN:-}"
EMAIL="${EMAIL:-}"
TRAEFIK_DASHBOARD_USER="${TRAEFIK_DASHBOARD_USER:-}"
TRAEFIK_DASHBOARD_PASSWORD="${TRAEFIK_DASHBOARD_PASSWORD:-}"

if [ -z "$MAIN_DOMAIN" ] || [ -z "$EMAIL" ] || [ -z "$TRAEFIK_DASHBOARD_USER" ] || [ -z "$TRAEFIK_DASHBOARD_PASSWORD" ]; then
    echo "You must set the following environment variables to run this script:"
    echo "  export MAIN_DOMAIN=yourdomain.com"
    echo "  export EMAIL=you@example.com"
    echo "  export TRAEFIK_DASHBOARD_USER=username"
    echo "  export TRAEFIK_DASHBOARD_PASSWORD=password"
    exit 1
fi

TRAEFIK_NETWORK="traefik-public"
TRAEFIK_VERSION="docker.io/library/traefik:latest"
PORTAINER_VERSION="portainer/portainer-ce:latest"
ACME_FILE="/mnt/data/traefik/acme.json"
TRAEFIK_SUBDOMAIN="traefik.${MAIN_DOMAIN}"
PORTAINER_SUBDOMAIN="portainer.${MAIN_DOMAIN}"

docker swarm init --advertise-addr "$(hostname -I | awk '{print $1}')" || true
docker network inspect $TRAEFIK_NETWORK >/dev/null 2>&1 || \
docker network create --driver=overlay --scope=swarm $TRAEFIK_NETWORK

sudo mkdir -p /mnt/data/traefik
sudo touch "$ACME_FILE"
sudo chmod 600 "$ACME_FILE"

TRAEFIK_DASHBOARD_PASSWORD_ENCRYPTED=$(openssl passwd -apr1 "$TRAEFIK_DASHBOARD_PASSWORD")

# Generate docker-compose.yml
cat <<EOF > docker-compose.yml
version: "3.8"

services:
  traefik:
    image: "docker.io/library/traefik:latest"
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
        - "traefik.http.routers.traefik.entrypoints=websecure"
        - "traefik.http.routers.traefik.service=api@internal"
        - "traefik.http.routers.traefik.tls.certresolver=le"
        - "traefik.http.middlewares.auth.basicauth.users=${TRAEFIK_DASHBOARD_USER}:$(openssl passwd -apr1 ${TRAEFIK_DASHBOARD_PASSWORD})"
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

networks:
  ${TRAEFIK_NETWORK}:
    external: true

volumes:
  portainer_data:
EOF

docker stack deploy -c docker-compose.yml traefik_portainer

echo "Traefik: https://${TRAEFIK_SUBDOMAIN}"
echo "Portainer: https://${PORTAINER_SUBDOMAIN}"
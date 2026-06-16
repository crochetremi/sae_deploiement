#!/bin/bash
set -e

BACKUP_DIR="$1"
VOLUME="sae_deploiement_nextcloud_data"

docker compose down

docker volume rm "${VOLUME}"
docker volume create "${VOLUME}"

docker run --rm \
    -v "${VOLUME}:/dest" \
    -v "$(realpath "$BACKUP_DIR"):/backup:ro" \
    alpine \
    sh -c "cd /dest && tar xzf /backup/${VOLUME}.tar.gz"

docker compose up -d

echo "Restauration terminée depuis : ${BACKUP_DIR}"
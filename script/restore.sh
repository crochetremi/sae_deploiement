#!/bin/bash
set -e

if [ -z "$1" ]; then
    exit 1
fi

BACKUP_DIR="$(realpath "$1")"

if [ ! -d "$BACKUP_DIR" ]; then
    exit 1
fi

docker compose down || true
docker rm -f bookstack_db nextcloud bookstack_app bookstack_ldap bookstack_ldap_admin nginx_proxy uptime-kuma 2>/dev/null || true

VOLUMES=(
    "sae_deploiement_bookstack_db_data_vanilla"
    "sae_deploiement_nextcloud_data"
    "sae_deploiement_bookstack_app_data_vanilla"
    "sae_deploiement_openldap_db_data_vanilla"
    "sae_deploiement_openldap_conf_data_vanilla"
)

for VOLUME in "${VOLUMES[@]}"; do
    FILE_PATH="$BACKUP_DIR/${VOLUME}.tar.gz"

    if [ -f "$FILE_PATH" ]; then
        docker volume rm -f "${VOLUME}" 2>/dev/null || true
        docker volume create "${VOLUME}"

        docker run --rm \
            -v "${VOLUME}:/dest" \
            -v "${BACKUP_DIR}:/backups:ro" \
            alpine \
            sh -c "cd /dest && tar xzf /backups/${VOLUME}.tar.gz"
            
    fi
done

docker compose up -d

echo "Restauration totale terminée depuis : ${BACKUP_DIR}"
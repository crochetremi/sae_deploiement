#!/bin/bash
set -e

BACKUP_DIR="$PWD/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

VOLUMES=(
    "sae_deploiement_bookstack_db_data_vanilla"
    "sae_deploiement_nextcloud_data"
    "sae_deploiement_bookstack_app_data_vanilla"
    "sae_deploiement_openldap_db_data_vanilla"
    "sae_deploiement_openldap_conf_data_vanilla"
)

for VOLUME in "${VOLUMES[@]}"; do
    docker run --rm \
        -v "${VOLUME}:/source:ro" \
        -v "${BACKUP_DIR}:/backup" \
        alpine \
        tar czf "/backup/${VOLUME}.tar.gz" -C /source .
        
done

echo "Sauvegarde terminée : ${BACKUP_DIR}"
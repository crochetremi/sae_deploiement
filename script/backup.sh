#!/bin/bash
set -e

BACKUP_DIR="$PWD/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

for VOLUME in sae_deploiement_bookstack_db_data_vanilla sae_deploiement_nextcloud_data sae_deploiement_bookstack_app_data_vanilla sae_deploiement_openldap_db_data_vanilla; do
    docker run --rm \
        -v "${VOLUME}:/source:ro" \
        -v "${BACKUP_DIR}:/backup" \
        alpine \
        tar czf "/backup/${VOLUME}.tar.gz" -C /source .
    echo "[OK] ${VOLUME} sauvegardé"
done

docker exec bookstack_db \
    mariadb-dump -u root -p"$(cat ./secrets/db_root_pwd.txt)" --all-databases \
    > "${BACKUP_DIR}/all_databases.sql"

echo "Sauvegarde finie : ${BACKUP_DIR}"
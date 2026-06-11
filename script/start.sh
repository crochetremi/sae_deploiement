#!/bin/bash

LDAP_PASS="adminpassword" 
docker compose up -d

sleep 10

ldapadd -H ldap://localhost:389 \
  -D "cn=admin,dc=mongroupe,dc=local" \
  -w $LDAP_PASS \
  -f structure.ldif


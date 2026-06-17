#!/bin/bash

LDAP_PASS="adminpassword" 

ldapadd -H ldap://localhost:389 \
  -D "cn=admin,dc=mongroupe,dc=local" \
  -w $LDAP_PASS \
  -f script/structure.ldif


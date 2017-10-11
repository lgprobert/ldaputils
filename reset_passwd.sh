#!/bin/bash

USERID=$1

BINDDN="cn=Manager,dc=soho,dc=local"
DN="uid=$USERID,ou=People,dc=soho,dc=local"

ldappasswd -H ldap://localhost -x -D $BINDDN -W -s $USERID $DN

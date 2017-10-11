#!/bin/bash 

usage()
{
  echo "usage: $0 -u <uid> -G group1,group2..." 
}

BASE=`grep "^BASE" /etc/openldap/ldap.conf | cut -d' ' -f2`
if [ -z $BASE ]; then
    echo "System is not configured with LDAP Base domain, please fix it."
    exit 1
fi
BASE_DOMAIN="ou=Group,$BASE"
BINDDN="cn=Manager,$BASE"

while getopts ":u:G:" opt_char
do
    case $opt_char in
        u)
            USER=$OPTARG
            ;;
        G)
            GRPS=$OPTARG
            ;;
        \?)
            echo "$OPTARG is not a valid option."
            usage
            exit
            ;;
    esac
done

if [ -z "$USER" ]; then 
    echo "User name can not be empty."
    exit 1
fi

GROUP_LIST=`echo $GRPS | awk 'BEGIN { 
    FS=","  
    ORS=" " 
} 
 
{  
    x=1 
    while ( x<NF ) { 
        print $x  
        x++ 
    } 
    print $NF "\n" 
} '`

PEOPLE_BASE="ou=People,$BASE"
SEARCH_RESULT=`ldapsearch -x -b "$PEOPLE_BASE" -s one -LLL "(uid=$USER)" uid | grep dn`
if [ -z "$SEARCH_RESULT" ]; then
    echo "$USER is not existed in LDAP, nothing can be done"
    exit 1
fi

if [ -e del_member.ldif ]; then
    rm del_member.ldif
fi
for GRP in $GROUP_LIST
do
    sed "s/DEPARTMENT/$GRP/; s/ACTION/delete/; s/USER/$USER/" grpMember.template >> del_member.ldif
done
sed -i "s/BASE_DOMAIN/$BASE_DOMAIN/g" del_member.ldif

ldapmodify -W -x -D "$BINDDN" -f del_member.ldif
rm del_member.ldif
echo "$USER is successfully removed from the group(s)."

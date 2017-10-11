#!/bin/bash 

usage()
{
  echo "usage: $0 -u <uid> [ -r ] -h <help>" 
  echo "    -r  : this optional command option will delete user's home directory along with the user".
}

BASE=`grep "^BASE" /etc/openldap/ldap.conf | cut -d' ' -f2`
BINDDN="cn=Manager,$BASE"
GROUP_BASE="ou=Group,$BASE"

if [ -z $BASE ]; then
    echo "System is not configured with LDAP Base domain, please fix it."
    exit 1
fi

DEL_HOME_DIR="false"

while getopts ":u:rh" opt_char
do
    case $opt_char in
        u)
            USERID=$OPTARG
            ;;
        r)
            DEL_HOME_DIR="true"
            ;;
        h)
            usage
            exit
            ;;
        \?)
            echo "$OPTARG is not a valid option."
            usage
            exit
            ;;
    esac
done

if [ -z "$USERID" ]; then 
    echo "User name can not be empty."
    exit 1
fi

PEOPLE_BASE="ou=People,$BASE"
SEARCH_RESULT=`ldapsearch -x -b "$PEOPLE_BASE" -s one -LLL "(uid=$USERID)" uid | grep dn`
if [ -z "$SEARCH_RESULT" ]; then
    echo "$USERID is not existed in LDAP, nothing can be done"
    exit 1
fi

if [ -e del_user.ldif ]; then
    rm del_user.ldif
fi
sed "s/USER/$USERID/g; s/BASE/$BASE/" del_user.template > del_user.ldif
for GRP in `ldapsearch -x -b $GROUP_BASE -s one -LLL "(memberuid=$USERID)" cn | grep ^cn | awk '{print $2}'`
do
    sed "s/DEPARTMENT/$GRP/; s/ACTION/delete/; s/USER/$USERID/" grpMember.template >> del_user.ldif
done
sed -i "s/BASE_DOMAIN/$GROUP_BASE/" del_user.ldif

ldapmodify -W -x -D $BINDDN -f del_user.ldif
rm del_user.ldif
if [ "$DEL_HOME_DIR" == "true" ]; then
    echo "Deleting $USERID home directory ..."
    rm -rf /home/$USERID
fi

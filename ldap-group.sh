#!/bin/bash 

usage()
{
  echo "usage: $0 -g <group name> [ -a (add new group) | -d (delete group) ]"
  echo "    -a  : is only to add department only."
  echo "    -d  : can be used to delete either department or user group."
}

BASE=`grep "^BASE" /etc/openldap/ldap.conf | cut -d' ' -f2`
if [ -z $BASE ]; then
    echo "System is not configured with LDAP Base domain, please fix it."
    exit 1
fi
BASE_DOMAIN="ou=Group,$BASE"
BINDDN="cn=Manager,$BASE"
ACTION=""

while getopts ":g:adh" opt_char
do
    case $opt_char in
        g)
            GRP_NAME=$OPTARG
            ;;
        a)
            ACTION="add"
            ;;
        d)
            ACTION="delete"
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

if [ -z "$GRP_NAME" ]; then 
    echo "Group name can not be empty."
    exit 1
fi

if [ -z "$ACTION" ]; then
    echo "Either '-a' (for add new group) or '-d' (for delete an existing group) must be specified"
    exit 1
elif [ "$ACTION" == "add" ]; then
    if ldapsearch -x -b $BASE_DOMAIN -s one -LLL "(cn=$GRP_NAME)" dn | grep -i $GRP_NAME > /dev/null
    then
        echo "$GRP_NAME is already existed, can't be added again"
        exit 1
    fi
elif [ "$ACTION" == "delete" ]; then
    if ! ldapsearch -x -b $BASE_DOMAIN -s one -LLL "(cn=$GRP_NAME)" dn | grep -i $GRP_NAME > /dev/null
    then
        echo "$GRP_NAME is not existed, can't be deleted."
        exit 1
    fi
fi

if [ -e groupAdm.ldif ]; then
    rm groupAdm.ldif
fi

# Determine new group number for "add" action
if [ "$ACTION" == "add" ]; then
    GRP_NUM=`ldapsearch -x -b $BASE_DOMAIN -s one -LLL "(gidNumber<=999)" gidNumber | grep gidNumber | awk '{ print $2 }' | sort | tail -1`
    if [ -z $GRP_NUM ]; then
        GRP_NUM=900
    fi
    GRP_NUM=`expr $GRP_NUM + 1`

    sed "s/BASE/$BASE/; s/DEPARTMENT/$GRP_NAME/g; s/ACTION/add/; s/GRP_NUM/$GRP_NUM/" group.template >> groupAdm.ldif
elif [ "$ACTION" == "delete" ]; then
    ldapdelete -W -D $BINDDN "cn=$GRP_NAME,$BASE_DOMAIN"
    if [ $? -eq 0 ]; then
        echo "$ACTION group $GRP_NAME succeed."
    else
        echo "$ACTION group $GRP_NAME failed."
    fi
    exit 
fi

ldapmodify -W -x -D $BINDDN -f groupAdm.ldif
if [ $? -eq 0 ]; then
    rm groupAdm.ldif
    echo "Successfully $ACTION group $GRP_NAME." 
else
    echo "$ACTION group $GRP_NAME failed."
fi

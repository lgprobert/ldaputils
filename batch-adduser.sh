#!/bin/bash 

usage()
{
  echo "usage: $0 -f <user_list in CSV format>"
}

BASE=`grep "^BASE" /etc/openldap/ldap.conf | cut -d' ' -f2`
if [ -z $BASE ]; then
    echo "System is not configured with LDAP Base domain, please fix it."
    exit 1
fi
PEOPLE_BASE="ou=People,$BASE"
BINDDN="cn=Manager,$BASE"

while getopts ":f:h" opt_char
do
    case $opt_char in
        f)
            FILE=$OPTARG
            if ! [ -e "$FILE" ]; then
                echo "$FILE is not existed, check again and continue."
                exit 1
            fi
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

if [ -n "$FILE" ]; then
    LASTUID=`ldapsearch -x -b $PEOPLE_BASE -s one -LLL uidNumber | grep uidNumber | awk '{ print $2 }' | sort | tail -1`
    i=1
    while IFS=, read USERID USER_DESC USER_MAIL USER_GROUP
    do
        UID_NUM=`expr $LASTUID + $i`
        bash ./ldap-adduser.sh -u "$USERID" -G "$USER_GROUP" -e "$USER_MAIL" -c "$USER_DESC" -U $UID_NUM -b
        i=`expr $i + 1`
    done < $FILE
    
    if [ -e new-user.ldif ]; then
        ldapmodify -x -D $BINDDN -W -f new-user.ldif
        if [ $? -eq 0 ]; then
            echo "All users in $FILE are added into LDAP, now creating home directories for users."
        else
            echo "Batch users add failed in LDAP add operation."
            rm new-user.ldif
            exit 1
        fi
        for USERID in `awk -F',' '{print $1}' $FILE`
        do
            echo "Creating home directory for $USERID"
            . ./mkhome.sh $USERID
        done
        rm $FILE
    else
        echo "Intermediate ldif file can not be found, there is something, program exits."
        exit 1
    fi
fi

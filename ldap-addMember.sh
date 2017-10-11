#!/bin/bash 

usage()
{
  echo "usage: $0 -u <uid> -G group1,group2..." 
}

add_ldapmember() {
    USERID=$1
    GRPS=$2
    if [ -z "$USERID" ]; then
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

    echo "Grouplist: $GROUP_LIST"
    BASE=`grep "^BASE" /etc/openldap/ldap.conf | cut -d' ' -f2`
    BASE_DOMAIN="ou=Group,$BASE"
    PEOPLE_BASE="ou=People,$BASE"
    SEARCH_RESULT=`ldapsearch -x -b "$PEOPLE_BASE" -s one -LLL "(uid=$USERID)" uid | grep dn`
    if [ -z "$SEARCH_RESULT" ]; then
        echo "$USERID is not existed in LDAP, nothing can be done"
        return 1
    fi

    for GRP in $GROUP_LIST
    do
        sed "s/DEPARTMENT/$GRP/; s/ACTION/add/; s/USER/$USERID/" grpMember.template >> add_member.ldif
    done
    sed -i "s/BASE_DOMAIN/$BASE_DOMAIN/g" add_member.ldif
    echo "$USERID is processed"
    return 0
}

BASE=`grep "^BASE" /etc/openldap/ldap.conf | cut -d' ' -f2`
if [ -z $BASE ]; then
    echo "System is not configured with LDAP Base domain, please fix it."
    exit 1
fi
BASE_DOMAIN="ou=Group,$BASE"
BINDDN="cn=Manager,$BASE"

while getopts ":u:G:f:h" opt_char
do
    case $opt_char in
        u)
            USERID=$OPTARG
            ;;
        G)
            GRPS=$OPTARG
            ;;
        f)
            FILE=$OPTARG
            ;;
        h)
            usage
            exit 0
            ;;
        \?)
            echo "$OPTARG is not a valid option."
            usage
            exit
            ;;
    esac
done

if [[ -n $FILE && -n $USERID ]] || [[ -n $FILE && -n $GRPS ]]; then
    echo "-f can not be assigned together with -u or -G"
    exit 1
elif [[ -n $FILE && ! -e $FILE ]]; then
    echo "$FILE is not found." 
    exit 1
fi

# delete add_member.ldif if there is it in directory
if [ -e add_member.ldif ]; then
    rm add_member.ldif
fi

# Add group member for single user
if [[ -n $USERID && -n $GRPS ]]; then
    add_ldapmember $USERID $GRPS
fi

# Add group member for multiple users from a file
if [[ -n $FILE ]]; then
    while IFS=: read USERID GRPS   
    do
        echo "Line: $USERID, $GRPS"
        add_ldapmember $USERID $GRPS
    done < $FILE
fi    

ldapmodify -W -x -D "$BINDDN" -f add_member.ldif
rm add_member.ldif
echo Succeed

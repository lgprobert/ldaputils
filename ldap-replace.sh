#!/bin/bash 

usage()
{
  echo "usage: $0 -u <uid> -G group1,group2..." 
    echo "      -b: (optional) base name for organization, like；dc=example,dc=com"
    echo "      -u: (required) uid of a user"
    echo "      -A: (required) attribute name, supported values are:"
    echo "              cn, uidNumber, loginShell, telephoneNumber, mail"
    echo "      -v: (required) attribute value which must be corresponding to attribute name"
    echo "      -f: (optional) CSV format data file, which is mutual exclusive to '-u', '-A', and '-v'."
}

BASE="dc=soho,dc=local"
BASE_DOMAIN="ou=People,$BASE"
BINDDN="cn=Manager,$BASE"

replace_attritues() {
    USERID=$1
    ATTR_NAME=$2
    ATTR_VALUE=$3

    DN="uid=$USERID,$BASE_DOMAIN"
    SEARCH_RESULT=`ldapsearch -x -b "$BASE_DOMAIN" -s one -LLL "(uid=$USERID)" | grep dn`
    if [ -z "$SEARCH_RESULT" ]; then
        echo "$USERID is not existed in LDAP, nothing can be done"
        return 1
    fi
    echo "dn: $DN" >> replace_attr.ldif
    echo "changetype: modify" >> replace_attr.ldif
    echo "replace: $ATTR_NAME" >> replace_attr.ldif
    echo "$ATTR_NAME: $ATTR_VALUE" >> replace_attr.ldif
    echo >> replace_attr.ldif
    return 0
}

while getopts ":u:b:f:A:v:h" opt_char
do
    case $opt_char in
        u)
            USERID=$OPTARG
            ;;
        b)
            BASE=$OPTARG
            BASE_DOMAIN="ou=People,$BASE"
            BINDDN="cn=Manager,$BASE"
            ;;
        A)
            ATTR_NAME=$OPTARG
            ;;
        v)
            ATTR_VALUE=$OPTARG
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

if [[ -n $FILE && -n $USERID ]]; then
    echo "-f can not be assigned together with -u -A and/or -v"
    exit 1
elif [[ -n $FILE && ! -e $FILE ]]; then
    echo "$FILE is not found." 
    exit 1
fi

# delete replace_attr.ldif if there is it in directory
if [ -e replace_attr.ldif ]; then
    rm replace_attr.ldif
fi

# Replace attribute value for single user
if [[ -n $USERID && -n $ATTR_NAME && -n $ATTR_VALUE ]]; then
    replace_attritues $USERID $ATTR_NAME $ATTR_VALUE
fi

# Replace attribute value for multiple users from a file
if [[ -n $FILE ]]; then
    while IFS=, read USERID ATTR_NAME ATTR_VALUE
    do
        echo "Line: $USERID, $ATTR_NAME, $ATTR_VALUE"
        replace_attritues $USERID $ATTR_NAME $ATTR_VALUE
    done < $FILE
fi    

ldapmodify -W -x -D "$BINDDN" -f replace_attr.ldif
#rm replace_attr.ldif
echo Succeed

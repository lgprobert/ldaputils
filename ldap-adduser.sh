#!/bin/bash 

usage()
{
  echo "usage: $0 -u <uid> -c <full name> -e <email_address> -s <shell> -G <department_name> -h <help>"
}

BASE=`grep "^BASE" /etc/openldap/ldap.conf | cut -d' ' -f2`
if [ -z $BASE ]; then
    echo "System is not configured with LDAP Base domain, please fix it."
    exit 1
fi
PEOPLE_BASE="ou=People,$BASE"
GROUP_BASE="ou=Group,$BASE"
BINDDN="cn=Manager,$BASE"
BATCH=false

while getopts ":u:c:s:e:G:U:hbm" opt_char
do
    case $opt_char in
        u)
            USERID=$OPTARG
            SEARCH_RESULT=`ldapsearch -x -b "$PEOPLE_BASE" -s one -LLL "(uid=$USERID)" uid | grep dn`
            if [ -n "$SEARCH_RESULT" ]; then
                echo "$USERID is existed in LDAP, choose another unused user ID"
                exit 1
            fi
            ;;
        c)
            FULLNAME=$OPTARG
	    ;;
	e)
            EMAIL=$OPTARG
	    ;;
        G)
            DEPT=$OPTARG
            if ! (grep $DEPT valid_group.list > /dev/null); then
                echo "Non-existed department, exit."
                exit 1
            fi 
            ;; 
        s)
            SHELL=$OPTARG
            ;; 
        U)          # uid number must be provided in batch mode, it is ignored in other cases
            UID_NUM=$OPTARG
            ;;
        b)          # batch mode
            BATCH=true
            ;;
        m)          # migrate home directory: keep current home directory
            ISMIGRATE=true
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

if [ -z "$USERID" ] || [ -z "$FULLNAME" ] || [ -z "$EMAIL" ] || [ -z "$DEPT" ]; then
    echo "Any of uid, full name, email address and department can not be empty."
    exit 1
fi

if [ "$BATCH" == "true" ] && [ -z $UID_NUM ]; then
    echo "uid number must be provided in batch mode from calling script."
    exit 1
fi 

# UID_NUM is globally controlled in batch-adduser.sh during batch mode, here only for add one user
if [[ "$BATCH" == "false" ]]; then
    LASTUID=`ldapsearch -x -b $PEOPLE_BASE -s one -LLL uidNumber | grep uidNumber | awk '{ print $2 }' | sort | tail -1`
    UID_NUM=`expr $LASTUID + 1`
fi

PASSWORD=`slappasswd -s $USERID`

if [ "$DEPT" == "Sales" ] || [ "$DEPT" == "Backoffice" ]; then
    SHELL=/bin/false
else
    SHELL=/bin/bash
fi

if [ "$BATCH" == "false" ] && [ -e new-user.ldif ]; then
    rm new-user.ldif
fi

# Use customized delimiter '%' to replace regular delimiter of sed because '$SHELL' contains '/'
sed "s%BASE%$BASE%g; s%USER%${USERID}%g; s%FULLNAME%$FULLNAME%; s%EMAIL%$EMAIL%; s%SHELL%$SHELL%; s%uidNumber/$UID_NUM; s%gidNumber%$UID_NUM; s%PASSWORD%$PASSWORD%; s%UID_NUM%$UID_NUM%g" user.template >> new-user.ldif
sed "s%DEPARTMENT%$DEPT%; s%USER%$USERID%; s%BASE_DOMAIN%$GROUP_BASE%; s%ACTION%add%" grpMember.template >> new-user.ldif

if [ "$BATCH" == "false" ]; then
    ldapmodify -x -D $BINDDN -W -f new-user.ldif

    if [ $? != 0 ]; then
        echo "There is error during user creation, check LDAP log, exiting."
        rm new-user.ldif
        exit 1
    else 
        echo "Create home directory for $USERID"
        if [ "$ISMIGRATE" == "true" ]; then
            sh ./mkhome.sh $USERID keep
        else
            sh ./mkhome.sh $USERID new
        fi
    fi
    rm new-user.ldif
else
    echo "$USERID is processed"
fi

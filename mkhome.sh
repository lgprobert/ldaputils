#!/bin/bash
USERID=$1
ISMIGRATE=$2
PASSWD=`getent passwd $USERID`
if [ -e /home/$USERID ]; then
    if [ "$ISMIGRATE" == "new" ]; then
        rm -rf /home/$USERID
    fi
fi
mkdir /home/$USERID
OWNER=`echo $PASSWD | awk -F ":" '{print $3":"$4}'`
cp /etc/skel/.bash* /home/$USERID
chown -R $OWNER /home/$USERID
chmod -R 700 /home/$USERID
echo "User $USERID's home directory /home/$USERID has been created."

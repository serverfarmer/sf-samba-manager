#!/bin/bash
. /opt/farm/scripts/functions.uid
. /opt/farm/scripts/functions.custom
. /opt/farm/ext/net-utils/functions
. /opt/farm/ext/keys/functions
# create Samba account:
# - first on local management server (to preserve UID)
# - then on specified Samba server (sf-samba-server and sf-php extensions required)
# - last on specified backup server (if not the same)
# Tomasz Klim, 2015-2016


MINUID=1600
MAXUID=1799


if [ "$2" = "" ]; then
	echo "usage: $0 <user> <samba-server[:port]> [backup-server[:port]]"
	exit 1
elif ! [[ $1 =~ ^[a-z0-9]+$ ]]; then
	echo "error: parameter $1 not conforming user name format"
	exit 1
elif [ -d /home/smb-$1 ]; then
	echo "error: user $1 exists"
	exit 1
elif [ "`resolve_host $2`" = "" ]; then
	echo "error: parameter $2 not conforming hostname format, or given hostname is invalid"
	exit 1
fi

uid=`get_free_uid $MINUID $MAXUID`

if [ $uid -lt 0 ]; then
	echo "error: no free UIDs"
	exit 1
fi

sambaserver=$2
backupserver=$3

if [ -z "${sambaserver##*:*}" ]; then
	sambahost="${sambaserver%:*}"
	sambaport="${sambaserver##*:}"
else
	sambahost=$sambaserver
	sambaport=22
fi

if [ "$backupserver" != "" ] && [ "$backupserver" != "$sambaserver" ]; then
	if [ "`resolve_host $backupserver`" = "" ]; then
		echo "error: parameter $3 not conforming hostname format, or given hostname is invalid"
		exit 1
	fi

	if [ -z "${backupserver##*:*}" ]; then
		backuphost="${backupserver%:*}"
		backupport="${backupserver##*:}"
	else
		backuphost=$backupserver
		backupport=22
	fi
fi

path=/home/smb-$1
useradd -u $uid -d $path -m -g sambashare -s /bin/false smb-$1
chmod 0711 $path
rm $path/.bash_logout $path/.bashrc $path/.profile

sambakey=`ssh_management_key_storage_filename $sambahost`
ssh -i $sambakey -p $sambaport root@$sambahost "useradd -u $uid -d $path -m -g sambashare -s /bin/false smb-$1"
ssh -i $sambakey -p $sambaport root@$sambahost "chmod 0711 $path"
ssh -i $sambakey -p $sambaport root@$sambahost "rm $path/.bash_logout $path/.bashrc $path/.profile"
ssh -i $sambakey -p $sambaport root@$sambahost "smbpasswd -a smb-$1"

if [ "$backupserver" != "" ] && [ "$backupserver" != "$sambaserver" ]; then
	backupkey=`ssh_management_key_storage_filename $backuphost`
	ssh -i $backupkey -p $backupport root@$backuphost "useradd -u $uid -d $path -m -g sambashare -s /bin/false smb-$1"
	ssh -i $backupkey -p $backupport root@$backuphost "chmod 0711 $path"
	ssh -i $backupkey -p $backupport root@$backuphost "rm $path/.bash_logout $path/.bashrc $path/.profile"
fi

#!/bin/bash
. /opt/farm/scripts/functions.uid
. /opt/farm/scripts/functions.custom
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
	echo "error: parameter 1 not conforming user name format"
	exit 1
elif ! [[ $2 =~ ^[a-z0-9.-]+[.][a-z0-9]+([:][0-9]+)?$ ]]; then
	echo "error: parameter 2 not conforming host name format"
	exit 1
elif [ -d /home/smb-$1 ]; then
	echo "error: user $1 exists"
	exit 1
elif [ "`getent hosts $2`" = "" ]; then
	echo "error: host $2 not found"
	exit 1
fi

uid=`get_free_uid $MINUID $MAXUID`

if [ $uid -lt 0 ]; then
	echo "error: no free UIDs"
	exit 1
fi

rserver=$2
if [ -z "${rserver##*:*}" ]; then
	rhost="${rserver%:*}"
	rport="${rserver##*:}"
else
	rhost=$rserver
	rport=22
fi

if [ "$3" != "" ] && [ "$3" != "$2" ]; then
	bserver=$3

	if ! [[ $bserver =~ ^[a-z0-9.-]+[.][a-z0-9]+([:][0-9]+)?$ ]]; then
		echo "error: parameter 3 not conforming host name format"
		exit 1
	fi

	if [ -z "${bserver##*:*}" ]; then
		bhost="${bserver%:*}"
		bport="${bserver##*:}"
	else
		bhost=$bserver
		bport=22
	fi

	if [ "`getent hosts $bhost`" = "" ]; then
		echo "error: host $bhost not found"
		exit 1
	fi
fi

path=/home/smb-$1
useradd -u $uid -d $path -m -g sambashare -s /bin/false smb-$1
chmod 0711 $path
rm $path/.bash_logout $path/.bashrc $path/.profile

rkey=`ssh_management_key_storage_filename $rhost`
ssh -i $rkey -p $rport root@$rhost "useradd -u $uid -d $path -m -g sambashare -s /bin/false smb-$1"
ssh -i $rkey -p $rport root@$rhost "chmod 0711 $path"
ssh -i $rkey -p $rport root@$rhost "rm $path/.bash_logout $path/.bashrc $path/.profile"
ssh -i $rkey -p $rport root@$rhost "smbpasswd -a smb-$1"

if [ "$3" != "" ] && [ "$3" != "$2" ]; then
	bkey=`ssh_management_key_storage_filename $bhost`
	ssh -i $bkey -p $bport root@$bhost "useradd -u $uid -d $path -m -g sambashare -s /bin/false smb-$1"
	ssh -i $bkey -p $bport root@$bhost "chmod 0711 $path"
	ssh -i $bkey -p $bport root@$bhost "rm $path/.bash_logout $path/.bashrc $path/.profile"
fi

#!/bin/sh

/opt/farm/scripts/setup/extension.sh sf-net-utils
/opt/farm/scripts/setup/extension.sh sf-farm-manager

ln -sf /opt/farm/ext/samba-manager/add-samba-user.sh /usr/local/bin/add-samba-user

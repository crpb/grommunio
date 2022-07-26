#!/usr/bin/env bash
zypper --non-interactive install --auto-agree-with-licenses yast2-nfs-client yast2-snapper snapper-zypp-plugin grub2-snapper-plugin snapper bash-completion jq
mkdir -p ~/.local/bash-completion
wget https://raw.githubusercontent.com/openSUSE/snapper/master/scripts/bash-completion.bash -O ~/.local/bash-completion/snapper

cat << EOF >> ~/.bashrc
for file in ~/.local/bash-completion/*; do test -f "$file" && . "$file"; done
alias snapconfs='snapper list-configs --columns config |tail -n +3'
EOF

source ~/.bashrc

#OVA has a snapshot, so we handle that with that.
cp /etc/snapper/config-templates/default /etc/snapper/configs/root
sed -i '$s/""/"root"/g' /etc/sysconfig/snapper
#Reload because of manual file-change
systemctl restart snapperd.service

#Add all btrfs-volumes with 'grom*' in name for more control of snapshots
#Grommunio-Chat always changes the owner of .snapshot - not using anyway
for path in $(mount -t btrfs |awk '/grom/ {print $3}' |grep -v chat); 
  do 
    conf=${path##*/}
    usr=$(stat -c "%U" $path)
    grp=$(stat -c "%G" $path)
    snapper -c $conf create-config $path
    #Maybe this helps in some way down the road...
    snapper -c $conf set-config ALLOW_USERS="$usr" ALLOW_GROUPS="$grp" SYNC_ACL="yes"
done




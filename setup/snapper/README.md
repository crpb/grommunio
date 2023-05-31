# setup.sh
Install Snapper-Utils and configure needed configs
```
Config            | Subvolume                  
------------------+---------------------------
grommunio-archive | /var/lib/grommunio-archive
grommunio-files   | /var/lib/grommunio-files  
gromox            | /var/lib/gromox            
root              | /   
```

# grombak

create a backup with help of the configured snapper profiles...

> backup and restore worked so far...  - for me, not you - try before buy

> > for now only **GROMOX** is handled !!!

## setup
```
#copy/link the script to some place
ln -s /root/scripts/setup/snapper/grombak /root/bin/grombak
#add cron-entry to root's crontab
crontab -l | cat<<EOF |crontab -
# We wan't the output via Mail, check /etc/aliases
5 1  * * * /root/bin/grombak 2>&1
EOF
```

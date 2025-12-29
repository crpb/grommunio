#!/usr/bin/env sh
# needed to whip this up after the migration to freshly created mailboxes had
# to be redone as i forgot to set the correct locale for the mailboxes.
# because of the source-language of the pst's a change of the locale afterwards
# wouldn't have been helpful. luckily i disabled the deletion of the PST's in
# exchange2grommunio.ps1 so i could just do the following
# ```
# systemctl stop nginx
# gromox-mbop foreach.mb echo-username |xargs -n 1 grommunio-admin user delete --yes
# systemctl restart gromox-http
# grommunio-admin fs clean  # which clears out /var/lib/gromox/{domain,user} from unkown shit
# grommunio-admin dbset grommunio-admin defaults-system user.lang de_DE
# grommunio-ldap-sync # or just grommunio-admin ldap downsync --complete -o 1
# ```
# and then import all those PST's in only ~3-5 hours vs. the complete export/import
# which took like 18 hours /(°o°)\ 
users=$(gromox-mbop foreach.mb echo-username |sort -r)

PSTPATH=/mnt/exchange/migration
mkdir -p "$PSTPATH"/bulkimport
for user in $users; do
	if [ -f "$PSTPATH"/"$user".pst ]; then
		echo gromox-e2ghelper -s  "$PSTPATH"/"$user".pst -u "$user" 2>&1 | tee "$PSTPATH"/bulkimport/"$user".log
		gromox-e2ghelper -s  "$PSTPATH"/"$user".pst -u "$user" 2>&1 | tee "$PSTPATH"/bulkimport/"$user".log
	fi
done

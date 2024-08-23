#!/bin/sh
QUERY='select username, maildir from users where maildir like "/var/lib/gromox/user/%"'
if [ $# = 1 ]; then
  USR="$1"
  QUERY="$QUERY AND username = \"${USR}\"" 
fi
mysql grommunio --skip-column-names \
 --execute="$QUERY" |
  while read -r username maildir; do
    printf '{ "username": "%s", "maildir": "%s", "permissions": %s }\n\n' \
      "$username" "$maildir" \
      "$(sqlite3 -json $maildir/exmdb/exchange.sqlite3 < /root/scripts/sql/exmdb-perms.sql)";
    done

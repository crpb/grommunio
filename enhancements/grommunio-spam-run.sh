#!/bin/bash

MYSQL_CFG="/etc/gromox/mysql_adaptor.cfg"

if [ ! -e "${MYSQL_CFG}" ] ; then
  echo "MySQL configuration not found. (${MYSQL_CFG})"
  exit 1
fi

MYSQL_PARAMS="--skip-column-names --skip-line-numbers"
MYSQL_USERNAME=$(sed -ne 's/mysql_username\s*=\s*\(.*\)\s*/-u\1/pI' ${MYSQL_CFG})
MYSQL_PASSWORD=$(sed -ne 's/mysql_password\s*=\s*\(.*\)\s*/-p\1/pI' ${MYSQL_CFG})
MYSQL_DBNAME=$(sed -ne 's/mysql_dbname\s*=\s*\(.*\)\s*/\1/pI' ${MYSQL_CFG})
MYSQL_HOST=$(sed -ne 's/mysql_host\s*=\s*\(.*\)\s*/-h\1/pI' ${MYSQL_CFG})
MYSQL_PORT=$(sed -ne 's/mysql_port\s*=\s*\(.*\)\s*/-P\1/pI' ${MYSQL_CFG})
# shellcheck disable=SC2016
MYSQL_QUERY='SELECT `username`, `maildir` from users where `id` <> 0 and `maildir` <> "";'
MYSQL_CMD=("mysql" ${MYSQL_PARAMS} "${MYSQL_USERNAME:=-uroot}" "${MYSQL_PASSWORD:=}" "${MYSQL_HOST:=-hlocalhost}" "${MYSQL_PORT}" "${MYSQL_DBNAME:=email}")
SQLITE_QUERY='select message_id,mid_string from messages where parent_fid=0x17;'
if ${MYSQL_CMD[@]}<<<"exit"&>/dev/null; then
  echo "${MYSQL_QUERY}" | ${MYSQL_CMD[@]} | while read -r USERNAME MAILDIR ; do
    echo "${SQLITE_QUERY}" | sqlite3 "${MAILDIR}/exmdb/exchange.sqlite3" -tabs -noheader | while read -r MESSAGEID MIDSTRING; do
      echo "Learning spam for user ${USERNAME}" | systemd-cat -t grommunio-spam-run
      MSGFILE="$MAILDIR/eml/$MIDSTRING"
      if [[ ! -f "$MSGFILE" ]]; then
        gromox-exm2eml -u "${USERNAME}" "${MESSAGEID}" 2>/dev/null | rspamc learn_spam "$MSGFILE" | systemd-cat -t grommunio-spam-run
      else
        rspamc learn_spam "$MSGFILE" | systemd-cat -t grommunio-spam-run
        # ??? this will always result in 0 as systemd-cat is run as the last command.
        EXITSTATUS=$?
        if [ ${EXITSTATUS} -eq 0 ]; then
          /usr/sbin/gromox-mbop -u "${USERNAME}" delmsg -f 0x17 "${MESSAGEID}" | systemd-cat -t grommunio-spam-run
        fi
      fi
    done
  done
else
  echo "MySQL-Connection couldn't be established, please check your configuration." |systemd-cat -t grommunio-spam-run -p err
fi

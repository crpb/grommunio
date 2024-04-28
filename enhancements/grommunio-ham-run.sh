#!/bin/bash
# vim:ts=2 sts=2 sw=2 et

if ! [ -e /etc/gromox/spamrun.cfg ]; then
  cat << EOF > /etc/gromox/spamrun.cfg
# SPAM #
# Only scan messages which are older than n days.
# Default: SPAMRUN_DAYS=7
SPAMRUN_DAYS=7
# To delete the message after the scan set to 'true' 
# Default: SPAMRUN_DELETE=false
SPAMRUN_DELETE=false

# HAM #
# Default: HAMRUN_FOLDER=
HAMRUN_FOLDER="NON-JUNK"
# Delete *copied* Mails which should be learned as HAM
# Default: HAMRUN_DELETE=false
HAMRUN_DELETE=false
EOF
fi


# source config file
if [ -r /etc/gromox/spamrun.cfg ]; then
  . /etc/gromox/spamrun.cfg
fi
SQLITE_QUERY="""
/* GET MESSAGES IN  HAM-FOLDER */
SELECT m.message_id,
  m.mid_string
  FROM messages m
  JOIN folders f
  ON m.parent_fid = f.folder_id
  JOIN folder_properties fp
  ON fp.folder_id = f.folder_id
  WHERE fp.propval LIKE ''${HAMRUN_FOLDER}''
-- DON'T LOOK INTO SUBDIRECTORIES
    AND f.parent_id = 9
  """

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
  MYSQL_QUERY="SELECT username,maildir from users where id <> 0 and maildir <> \"\";"
  MYSQL_CMD=("mysql" "${MYSQL_PARAMS}" "${MYSQL_USERNAME:=-uroot}" "${MYSQL_PASSWORD:=}" "${MYSQL_HOST:=-hlocalhost}" "${MYSQL_DBNAME:=grommunio}")
  # shellcheck disable=SC2068
  if ${MYSQL_CMD[@]}<<<"exit"&>/dev/null; then
    echo "${MYSQL_QUERY}" | ${MYSQL_CMD[@]} | while read -r USERNAME MAILDIR ; do
    sqlite3 -readonly -tabs -noheader "${MAILDIR}/exmdb/exchange.sqlite3" "$SQLITE_QUERY" |
      while read -r MESSAGEID MIDSTRING; do
        echo "Learning spam for user ${USERNAME}" | systemd-cat -t grommunio-spam-run
        MSGFILE="$MAILDIR/eml/$MIDSTRING"
        if [[ ! -f "$MSGFILE" ]]; then
          gromox-exm2eml -u "${USERNAME}" "${MESSAGEID}" 2>/dev/null | rspamc learn_hpam | systemd-cat -t grommunio-spam-run
        else
          rspamc learn_ham --header 'Learn-Type: bulk' "$MSGFILE" | systemd-cat -t grommunio-spam-run
        fi
        if [ "${HAMRUN_DELETE}" == "true" ]; then
          /usr/sbin/gromox-mbop -u "${USERNAME}" delmsg -f 0x17 "${MESSAGEID}" | systemd-cat -t grommunio-spam-run
        fi
      done
      rm -f "${SPAMLIST}"
    done
  else
    echo "MySQL-Connection couldn't be established, please check your configuration." | systemd-cat -t grommunio-spam-run -p err
  fi





#!/bin/bash
# vim:ts=2 sts=2 sw=2 expandtab
# Auto Config if not present
if ! [ -e /etc/gromox/spamrun.cfg ]; then
  cat << EOF > /etc/gromox/spamrun.cfg
# rspamd might run somewhere else and isn't configured as multi-instance
# see rspamc(1) for more options
# RSPAMC_OPTS=( -h a.b.c.d:1234 -P myverysecurepass )
RSPAMC_OPTS=()

# Use soft-delete with gromox-mbop delmsg? 
SOFT_DELETE=true

# SPAM #
# Only scan messages which are older than n days.
# Default: SPAMRUN_DAYS=7
SPAMRUN_DAYS=7
# Delete the message after we scanned it? 
# Default: SPAMRUN_DELETE=false
SPAMRUN_DELETE=false

# HAM #
# Default: HAMRUN_FOLDER=TRAIN-HAM
HAMRUN_FOLDER=TRAIN-HAM
# Delete *copied* Mails which should be learned as HAM?
# Default: HAMRUN_DELETE=false
HAMRUN_DELETE=false
EOF
fi

RSPAMC_OPTS=()
SPAMRUN_DAYS=7
SPAMRUN_DELETE=false
if [ -r /etc/gromox/spamrun.cfg ]; then
  . /etc/gromox/spamrun.cfg
fi
if [ -z ${SPAMRUN_DAYS+x} ]; then
  SQLITE_QUERY='select message_id,mid_string from messages where parent_fid=0x17 and is_deleted = 0;'
else
  read -r -d '' SQLITE_QUERY << EOSQL
SELECT m.message_id,m.mid_string
FROM messages m
INNER JOIN message_properties mp1
ON mp1.message_id = m.message_id
AND mp1.proptag = 235274304
AND (mp1.propval/10000000-11644473600) < unixepoch('now','-$SPAMRUN_DAYS days')
-- DON'T LOOK INTO SUBDIRECTORIES
WHERE m.parent_fid = 0x17
-- DON'T GET SOFTDELETED
AND m.is_deleted = 0
;
EOSQL

fi
# add "-d" to delete junk emails after they have been learned
if [ "$1" = "-d" ]
then
  SPAMRUN_DELETE=true
fi

MYSQL_CFG="/etc/gromox/mysql_adaptor.cfg"
if [ ! -e "${MYSQL_CFG}" ] ; then
  echo "MySQL configuration not found. ($MYSQL_CFG)"
  exit 1
fi
MYSQL_PARAMS="--skip-column-names --skip-line-numbers"
MYSQL_USERNAME=$(sed -ne 's/^mysql_username\s*=\s*\(.*\)/\1/p' ${MYSQL_CFG})
if [ -z "$MYSQL_USERNAME" ]; then
  MYSQL_USERNAME="root"
fi
MYSQL_PASSWORD=$(sed -ne 's/^mysql_password\s*=\s*\(.*\)/\1/p' ${MYSQL_CFG})
MYSQL_DBNAME=$(sed -ne 's/^mysql_dbname\s*=\s*\(.*\)/\1/p' ${MYSQL_CFG})
if [ -z "$MYSQL_DBNAME" ]; then
  MYSQL_DBNAME="grommunio"
fi
if [ "${MYSQL_DBNAME:0:1}" = "-" ]; then
  echo "Cannot use that dbname: ${MYSQL_DBNAME}"
  exit 1
fi
MYSQL_HOST=$(sed -ne 's/^mysql_host\s*=\s*\(.*\)/-h\1/p' ${MYSQL_CFG})
if [ -z "$MYSQL_HOST" ]; then
  MYSQL_HOST="localhost"
fi
MYSQL_QUERY="SELECT username,maildir from users where id <> 0 and maildir <> \"\";"

CONFIG_FILE=$(mktemp)
cat <<CONFFILE >"${CONFIG_FILE}"
[client]
user=${MYSQL_USERNAME}
password='${MYSQL_PASSWORD}'
host=${MYSQL_HOST}
database=${MYSQL_DBNAME}
CONFFILE

cleanup() { rm -f "$CONFIG_FILE" ; }
trap cleanup EXIT

MYSQL_CMD="mysql --defaults-file=${CONFIG_FILE} ${MYSQL_PARAMS}"
# shellcheck disable=SC2068
if ${MYSQL_CMD}<<<"exit"&>/dev/null; then
  ${MYSQL_CMD} --execute "${MYSQL_QUERY}" | while read -r USERNAME MAILDIR; do
  sqlite3 -batch -readonly -tabs -noheader "${MAILDIR}/exmdb/exchange.sqlite3" "$SQLITE_QUERY" |
    while read -r MESSAGEID MIDSTRING; do
      MBOP_CMD="$(command -v gromox-mbop)"
      MBOP_CMD="$MBOP_CMD -u "$USERNAME" delmsg"
      if [ $SOFT_DELETE = "true" ]; then
        MBOP_CMD="$MBOP_CMD --soft"
      fi
      echo "Learning spam for user ${USERNAME}" | systemd-cat -t grommunio-spam-run -p info
      MSGFILE="$MAILDIR/eml/$MIDSTRING"
      if [[ ! -f "$MSGFILE" ]]; then
        gromox-exm2eml -u "${USERNAME}" "${MESSAGEID}" 2>/dev/null | rspamc ${RSPAMC_OPTS[@]} learn_spam | systemd-cat -t grommunio-spam-run -p debug
      else
        rspamc ${RSPAMC_OPTS[@]} --header 'Learn-Type: bulk' learn_spam "$MSGFILE" | systemd-cat -t grommunio-spam-run -p debug
      fi
      if [ "${SPAMRUN_DELETE}" = "true" ]; then
        $MBOP_CMD -f 0x17 "${MESSAGEID}" | systemd-cat -t grommunio-spam-run -p notice
      fi
    done
  done
else
  echo "MySQL-Connection couldn't be established, please check your configuration." | systemd-cat -t grommunio-spam-run -p err
fi

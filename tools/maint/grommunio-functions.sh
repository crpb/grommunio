#!/bin/bash

# /usr/local/bin/grommunio-functions.sh

# This script is a function library for grommunio
# Version: 0.9.3 - 2025-02-18
#
# Copyright 2025 Christopher Bock <christopher@bocki.com> & Miguel da Silva, Contauro AG <midas@contauro.com>


### Public function to retrieve all domains
grom_domains() { grommunio-admin domain list | awk '{print $2}' ; }


### Public function to retrieve all users for a specified domain or for all domains
grom_users() {
  local domains
  if [[ "$#" -ge 1 ]]; then
    domains=$(grep "^$1" <<< "$(grom_domains)")
  else
    domains=$(grom_domains)
  fi
  for dom in $domains; do \
    domID=$(grommunio-admin domain query -f domainname="$dom" ID)
    # remove distribution lists (i.e. users without maildir)
    grommunio-admin user query -s username -f domainID="$domID" username maildir | awk '$2 != "" && NR>1 {print $1}'
  done
}


### Internal function to retrieve the mail directory on disk for a specified user
_grom_query_maildir(){
  grommunio-admin user query --filter username="$1" maildir
}


### Internal function to retrieve the domain for a specified user
_grom_query_domainname(){
  grommunio-admin domain query --filter ID="$(grommunio-admin user query --filter username="$1" domainID)" domainname
}


### Internal function to translate folder types into IDs
_get_folder_id(){
  # translate our synthetic folder names into real mapi folder ids
  local fid
  case "$1" in
    "INBOX")   fid=0xd;;
    "OUTBOX")  fid=0xc;;
    "DRAFT")   fid=0xe;;
    "SENT")    fid=0xa;;
    "DELETED") fid=0xb;;
    "JUNK")    fid=0x17;;
    "all")     fid=0x9;;
  esac
  echo $fid
}


### Internal function to translate message classes into IDs
_get_message_class_id(){
  # translate our synthetic message type into real mapi message class ids
  local cid
  case "$1" in
    "CALENDAR")    cid="IPM.Appointment";;
    "CONTACTS")    cid="IPM.Contact";;
    "JOURNAL")     cid="IPM.Activity";;
    "TASKS")       cid="IPM.Task";;
    "NOTES")       cid="IPM.StickyNote";;
    "all")         cid="all";;
  esac
  echo $cid
}


### Internal function to purge orphaned messages and attachments from disk
_grom_cleanup() {
  local mdir

  # define function
  _grom_users="${_grom_users:=$(grom_users)}"

  # Call without parameters, apply default values
  if [[ "$#" -eq 0 ]]; then
    for user in $_grom_users; do
      _grom_cleanup "$user"
    done
  fi

  # Call with user
  if [[ "$#" -eq 1 ]]; then
    if [[ "$_grom_users" =~ $1 ]]; then
      user="$1"
      mdir="$(_grom_query_maildir "$user")"
      (
        printf '%s: Cleaning mail directory...\n' "$user"
        /usr/sbin/gromox-mbop -d "$mdir" purge-datafiles 2>&1 || printf '%s: Error: Purging datafiles failed.\n' "$user"
      ) | logger -t grom_cleanup
    fi
  fi
}


### Public function to clean up orphaned messages and attachments from disk
grom_cleanup() {
  local maildir
  local usage="Usage: $FUNCNAME domain"

  # Retrieve domains globally
  _grom_domains="${_grom_domains:=$(grom_domains)}"

  # Verify if mandatory arguments are set
  if [[ "$#" -eq 0 ]]; then
    echo $"$usage"; exit 1
  fi

  # Verify domain
  if ! [[ "$_grom_domains" =~ "$1" || "$1" = "all" ]]; then
    echo "Error: Domain '$1' does not exist." >&2; echo $"$usage"; exit 1
  fi
  domain=$1

  # Define _grom_users globally depending on domain parameter
  if [[ "$domain" = "all" ]]; then
    _grom_users="$(grom_users)"
  else
    _grom_users="$(grom_users $domain)"
  fi

  # Loop over users
  for user in $_grom_users; do
    _grom_cleanup "$user" 
  done
}


### Internal function to repair mailboxes
_grom_repair_mailboxes() {
  local user dbfile
  local cnt=0

  # define function
  _grom_users="${_grom_users:=$(grom_users)}"

  # Call without parameters, apply default values
  if [[ "$#" -eq 0 ]]; then
    for user in $_grom_users; do
      _grom_repair_mailboxes "$user"
    done
  fi

  # Call with user
  if [[ "$#" -eq 1 ]]; then
    if [[ "$_grom_users" =~ "$1" ]]; then
      user="$1"
      dbfile="$(_grom_query_maildir $user)/exmdb/exchange.sqlite3"
      logger -t grom_repair_mailbox "$user: Verifying mailbox..."
      cnt=$(/usr/sbin/gromox-mbck "$dbfile" 2> >(logger -t grom_repair_mailbox) | tail -1 | awk '$3=="problems" {print $2}')
      logger -t grom_repair_mailbox "$user: ${cnt:=0} issues found"

      # If necessary repair the mailbox with the -p flag
      if [[ $cnt -gt 0 ]]; then
	cnt=$(/usr/sbin/gromox-mbck -p "$dbfile" 2> >(logger -t grom_repair_mailbox) | awk -F'[][ ]' 'NR==2 && $(NF-1)=="fixed" {print $(NF-5)}')
	logger -t grom_repair_mailbox "$user: ${cnt:=0} issues fixed"
      fi
    fi
  fi
}


### Public function to repair mailboxes
grom_repair_mailboxes() {
  local maildir
  local usage="Usage: $FUNCNAME domain"

  # Retrieve domains globally
  _grom_domains="${_grom_domains:=$(grom_domains)}"

  # Verify if mandatory arguments are set
  if [[ "$#" -eq 0 ]]; then
    echo $"$usage"; exit 1
  fi

  # Verify domain
  if ! [[ "$_grom_domains" =~ "$1" || "$1" = "all" ]]; then
    echo "Error: Domain '$1' does not exist." >&2; echo $"$usage"; exit 1
  fi
  domain=$1

  # Define _grom_users globally depending on domain parameter
  if [[ "$domain" = "all" ]]; then
    _grom_users="$(grom_users)"
  else
    _grom_users="$(grom_users $domain)"
  fi

  # Loop over users
  for user in $_grom_users; do
    _grom_repair_mailboxes "$user"
  done
}


### Internal function to query SQLite database for messages to be deleted after x days
_grom_query_purge() {
  local dbfile fields folder_id days
  local sql

  # Call with user, query-type, folder-id, retention-days
  # Verify if mandatory arguments are set
  if [[ "$#" -ne 4 ]]; then
    logger -t _grom_query_purge "Error: mandatory arguments are missing"; exit 1
  fi

  dbfile="$1"
  [[ "$2" = "count" ]] && fields="count(m.message_id)" || fields="f.folder_id||'|'||m.message_id"
  folder_id=$3
  days=$4

  # basic query
  sql="with recursive folder_hierarchy as (
  select f.folder_id, f.parent_id from folders f where f.folder_id = $folder_id
  UNION ALL
  select f.folder_id, f.parent_id from folders f inner join folder_hierarchy fh on f.parent_id = fh.folder_id
)
select ${fields}
--select m.message_id, datetime(mp1.propval/10000000-11644473600,'unixepoch') as last_modification_time, f.propval as folder_type
from messages m
-- retrieve the folder hierarchy starting with the user-specified folder
inner join folder_hierarchy fh on fh.folder_id = m.parent_fid
-- restrict to email folders (container class=>907214879 must be IPF.Note) as we must not deleted old calendar or contact items
inner join folder_properties f on f.folder_id = m.parent_fid and f.proptag = 907214879 and f.propval = 'IPF.Note'
-- restrict to messages with mlast_modification_time=>80583072 older than x days (convert to unix epoch before compare)
inner join message_properties mp1 on mp1.message_id = m.message_id and mp1.proptag = 805830720 and (mp1.propval/10000000-11644473600) < unixepoch('now','-$days days')
where 1=1
-- exclude messages in the folder 'Drafts' unless explicitly selected
and ($folder_id = 0xe or m.parent_fid != 0xe)
order by m.message_id asc;"

  printf '%s' "$(sqlite3 -noheader -batch "$dbfile" "${sql}")"
}


### Internal function to retrieve count of messages to be deleted after x days
_grom_query_purge_count() {
  local user folder retention_days
  local dbfile folder_id all_retention_days junk_retention_days

  ## Set default values
  # Purge folders 'Deleted Items' or 'Junk Email' after 30 days
  junk_retention_days=30
  # Purge all folders after 180 days
  all_retention_days=180

  # define function
  _grom_users="${_grom_users:=$(grom_users)}"

  if [[ "$#" -eq 0 ]]; then
    for user in $_grom_users; do
      # Junk folders only
      printf '%s;%s junk\n' "$user" "$(_grom_query_purge_count "$user" "JUNK" "$junk_retention_days")"

      # All folders
      printf '%s;%s old\n' "$user" "$(_grom_query_purge_count "$user" "all" "$all_retention_days")"

    done
  fi

  if [[ "$#" -eq 3 ]]; then
    if [[ "$_grom_users" =~ "$1" ]]; then
      user="$1"
      dbfile="$(_grom_query_maildir $user)/exmdb/exchange.sqlite3"
      folder=$2
      folder_id=$(_get_folder_id "$folder")
      retention_days=$3
      echo $(_grom_query_purge "$dbfile" "count" "$folder_id" "$retention_days")
    fi
  fi

}


### Internal function to delete messages after x days
_grom_purge_messages() {
  local user folder retention_days
  local folder_id all_retention_days junk_retention_days message_type
  local dbfile obj msgid fid
  local cnt=0

  ## Set default values
  # Purge folders 'Deleted Items' and 'Junk Email' after 30 days
  junk_retention_days=30
  # Purge all folders after 180 days
  all_retention_days=180

  # define function
  _grom_users="${_grom_users:=$(grom_users)}"

  # Call without parameters, apply default values
  if [[ "$#" -eq 0 ]]; then
    for user in $_grom_users; do
      # Junk folders only
      _grom_purge_messages "$user" "JUNK" "$junk_retention_days"

      # All folders
      _grom_purge_messages "$user" "all" "$all_retention_days"
    done
  fi

  # Call with user, folder and retention_days
  if [[ "$#" -eq 3 ]]; then
    if [[ "$_grom_users" =~ "$1" ]]; then
      user="$1"
      folder=$2
      retention_days=$3
      dbfile="$(_grom_query_maildir $user)/exmdb/exchange.sqlite3"
      folder_id=$(_get_folder_id "$folder")
      
      # Set message type for output
      [[ "$folder" = "all" ]] && message_type="old" || message_type=$(echo "$folder" | tr '[:upper:]' '[:lower:]')

      # log message count
      cnt=$(_grom_query_purge "$dbfile" "count" "$folder_id" "$retention_days")
      logger -t grom_purge_messages "$user: $cnt $message_type messages to remove"

      # retrieve message ids
      for obj in $(_grom_query_purge "$dbfile" "data" "$folder_id" "$retention_days"); do
        # split obj into folder-id and message-id
        IFS=\| read -r fid msgid <<< $obj

        # delete the message suppressing success messages
	if ! /usr/sbin/gromox-mbop -u $user delmsg -f $fid $msgid >/dev/null 2> >(logger -t grom_purge_messages); then
          ((cnt=cnt-1))
          printf '%s: Error: Deleting message %s/%s failed.' "$user" "$fid" "$msgid" | logger -t grom_purge_messages
        fi
      done
      if [[ $cnt -gt 0 ]]; then
        logger -t grom_purge_messages "$user: $cnt $message_type messages deleted"
      fi
      echo $cnt
    fi
  fi
}


### Public function to retrieve count of messages to be deleted after x days
grom_query_purge_count() {
  local domain user folder retention_days
  local usage="Usage: $FUNCNAME domain (INBOX|OUTBOX|DRAFT|SENT|DELETED|JUNK|all) retention_days"

  # Retrieve domains globally
  _grom_domains="${_grom_domains:=$(grom_domains)}"

  # Verify if mandatory arguments are set
  if [[ "$#" -ne 3 ]]; then
    echo $"$usage"; exit 1
  fi

  # Verify domain
  if ! [[ "$_grom_domains" =~ "$1" || "$1" = "all" ]]; then
    echo "Error: Domain '$1' does not exist." >&2; echo $"$usage"; exit 1
  fi
  domain=$1

  # Define _grom_users globally depending on domain parameter
  if [[ "$domain" = "all" ]]; then
    _grom_users="$(grom_users)"
  else
    _grom_users="$(grom_users $domain)"
  fi

  # Verify if folder is allowed
  folder=$2
  if [[ -z $(_get_folder_id "$folder") ]]; then
    echo "Error: Folder '$2' is not allowed." >&2; echo $"$usage"; exit 1
  fi

  # Verify if retention days is an integer
  retention_days=$3
  re='^[0-9]+$'
  if ! [[ $retention_days =~ $re ]] ; then
    echo "Error: Retention days '$3' is not an integer." >&2; echo $"$usage"; exit 1
  fi

  # Loop over users
  for user in $_grom_users; do
    printf '%s;%s\n' "$user" "$(_grom_query_purge_count "$user" "$folder" "$retention_days")"
  done
}


### Public function to delete messages after x days
grom_purge_messages() {
  local domain user folder retention_days
  local usage="Usage: $FUNCNAME domain (INBOX|OUTBOX|DRAFT|SENT|DELETED|JUNK|all) retention_days"
  local cnt=0

  # Retrieve domains globally
  _grom_domains="${_grom_domains:=$(grom_domains)}"

  # Verify if mandatory arguments are set
  if [[ "$#" -ne 3 ]]; then
    echo $"$usage"; exit 1
  fi

  # Verify domain
  if ! [[ "$_grom_domains" =~ "$1" || "$1" = "all" ]]; then
    echo "Error: Domain '$1' does not exist." >&2; echo $"$usage"; exit 1
  fi
  domain=$1

  # Define _grom_users globally depending on domain parameter
  if [[ "$domain" = "all" ]]; then
    _grom_users="$(grom_users)"
  else
    _grom_users="$(grom_users $domain)"
  fi

  # Verify if folder is allowed
  folder=$2
  if [[ -z $(_get_folder_id "$folder") ]]; then
    echo "Error: Folder '$2' is not allowed." >&2; echo $"$usage"; exit 1
  fi

  # Verify if retention days is an integer
  retention_days=$3
  re='^[0-9]+$'
  if ! [[ $retention_days =~ $re ]] ; then
     echo "Error: Retention days '$3' is not an integer." >&2; echo $"$usage"; exit 1
  fi

  # Loop over users
  for user in $_grom_users; do
    cnt=$(_grom_purge_messages "$user" "$folder" "$retention_days")

    # If necessary clean the maildir
    if [[ $cnt -gt 0 ]]; then
      _grom_cleanup $user
    fi
  done
}


### Internal function to query SQLite database for calendar/contact/note items to be backed up
_grom_query_backup() {
  local dbfile fields message_class_id
  local sql

  # Call with user query-type, message-class-id
  # Verify if mandatory arguments are set
  if [[ "$#" -ne 3 ]]; then
    logger -t _grom_query_backup "Error: mandatory arguments are missing"; exit 1
  fi

  dbfile="$1"
  [[ "$2" = "count" ]] && fields="count(m.message_id)" || fields="mp1.propval||'|'||replace(replace(substr(f.propval,5)||'s','Appointments','Calendar'),'Journals','Journal')||'|'||m.message_id"
  message_class_id="$3"

  # basic query
  sql="SELECT ${fields}
FROM messages m
INNER JOIN folder_properties f ON f.folder_id = m.parent_fid
AND f.proptag = 907214879
AND f.propval IN (  'IPF.Appointment',
                    'IPF.Journal',
                    'IPF.StickyNote',
                    'IPF.Task',
                    'IPF.Contact')
INNER JOIN message_properties mp1 ON mp1.message_id = m.message_id
AND mp1.proptag = 1703967
AND mp1.propval IN (  'IPM.Appointment',
                      'IPM.Activity',
                      'IPM.StickyNote',
                      'IPM.Task',
                      'IPM.Contact')
INNER JOIN folder_properties f2 ON f2.folder_id = m.parent_fid
AND f2.proptag = 805371935
WHERE 1=1
  AND ('$message_class_id' = 'all'
  OR mp1.propval = '$message_class_id') -- exlude deleted, drafts, junk folders
AND m.parent_fid NOT IN (0xb,0xe,0x17)
ORDER BY m.message_id ASC;"

  printf '%s' "$(sqlite3 -batch -readonly -noheader "$dbfile" "${sql}")"
}


### Internal function to backup calendar/contact/note items
_grom_backup_objects() {
  local user target_folder message_type
  local message_class_id msg_type_out
  local dbfile obj msgclass fname msgid
  local exportbin ext
  local cnt=0

  # define function
  _grom_users="${_grom_users:=$(grom_users)}"

  # Call without parameters, apply default values
  if [[ "$#" -eq 0 ]]; then
    for user in $_grom_users; do
      # All message_types
      message_type="all"
      target_folder="~/"
      _grom_backup_objects "$user" "$target_folder" "$message_type"
    done
  fi

  # Call with user, target_folder, message_type
  if [[ "$#" -eq 3 ]]; then
    if [[ "$_grom_users" =~ "$1" ]]; then
      user="$1"
      target_folder="$2"
      message_type="$3"
      dbfile="$(_grom_query_maildir $user)/exmdb/exchange.sqlite3"
      message_class_id=$(_get_message_class_id "$message_type")

      # Set message type for output
      [[ "$message_type" = "all" ]] && msg_type_out="store" || msg_type_out=$(echo "$message_type" | tr '[:upper:]' '[:lower:]')

      # log message count
      cnt=$(_grom_query_backup "$dbfile" "count" "$message_class_id")
      logger -t grom_backup_objects "$user: $cnt $msg_type_out items to backup"

      # retrieve message ids
      for obj in $(_grom_query_backup "$dbfile" "data" "$message_class_id"); do
        # split obj into message-class folder-name and message-id
        IFS=\| read -r msgclass fname msgid <<< $obj

        # create the folder
        mkdir -p "$target_folder/$fname" || printf '%s: Error: The folder %s could not be created.' "$user" "$target_folder/$fname" | logger -t grom_backup_objects

        # set gromox export binary and file extension depending on message class
        case "$msgclass" in
          "IPM.Appointment")  exportbin="gromox-exm2ical"; ext="ics";;
          "IPM.Contact")      exportbin="gromox-exm2vcf";  ext="vcf";;
          *)                  exportbin="gromox-exm2eml";  ext="eml";;
        esac

	# export the message
	if ! $exportbin -u "$user" "$msgid" > "$target_folder/$fname/$msgid.$ext" 2> >(logger -t grom_backup_objects); then
          ((cnt=cnt-1))
          printf '%s: Error: Exporting %s item %s/%s.%s failed.' "$user" "$msgclass" "$fname" "$msgid" "$ext" | logger -t grom_backup_objects
        fi   
      done
      if [[ $cnt -gt 0 ]]; then
        logger -t grom_backup_objects "$user: $cnt $msg_type_out items exported"
      fi
      echo $cnt
    fi
  fi
}


### Public function to backup calendar/contact/note items
grom_backup_objects() {
  local domain target_folder message_type
  local tempdir user
  local uid domname
  local usage="Usage: $FUNCNAME domain target_folder (CALENDAR|CONTACTS|JOURNAL|TASKS|NOTES|all)"
  local cnt=0

  # Verify if required binaries exist
  command -v gromox-exm2eml >/dev/null 2>&1 || { echo >&2 "Error: gromox-exm2eml is required but not installed."; exit 1; }
  command -v gromox-exm2ical >/dev/null 2>&1 || { echo >&2 "Error: gromox-exm2ical is required but not installed."; exit 1; }
  command -v gromox-exm2vcf >/dev/null 2>&1 || { echo >&2 "Error: gromox-exm2vcf is required but not installed."; exit 1; }
  command -v bzip2 >/dev/null 2>&1 || { echo >&2 "Error: bzip2 is required but not installed."; exit 1; }

  # Retrieve domains globally
  _grom_domains="${_grom_domains:=$(grom_domains)}"

  # Verify if mandatory arguments are set
  if [[ "$#" -ne 3 ]]; then
    echo $"$usage"; exit 1
  fi

  # Verify domain
  if ! [[ "$_grom_domains" =~ "$1" || "$1" = "all" ]]; then
    echo "Error: Domain '$1' does not exist." >&2; echo $"$usage"; exit 1
  fi
  domain=$1

  # Define _grom_users globally depending on domain parameter
  if [[ "$domain" = "all" ]]; then
    _grom_users="${_grom_users:=$(grom_users)}"
  else
    _grom_users="${_grom_users:=$(grom_users $domain)}"
  fi

  # Verify target_folder
  if ! [[ -d "$2" ]]; then
    echo "Error: Target folder '$2' does not exist." >&2; echo $"$usage"; exit 1
  fi
  target_folder=$2

  # Verify if message type is allowed
  message_type="$3"
  if [[ -z $(_get_message_class_id "$message_type") ]]; then
    echo "Error: Message type '$3' is not allowed." >&2; echo $"$usage"; exit 1
  fi

  # Create temp directory
  tempdir=$(mktemp -d)
  trap 'rm -rf -- "$tempdir"' EXIT

  # Loop over users
  for user in $_grom_users; do
    # split user into uid and domname parts
    IFS=\@ read -r uid domname <<< $user
    cnt=$(_grom_backup_objects "$user" "$tempdir/$domname/$uid" "$message_type")
  done
  # tar and compress the output and store it to target folder
  tar -cjf "$target_folder/backup-$1-$3_$(date +'%Y%m%d-%H%M%S').tar.bz2" -C $tempdir .
}


### Internal function to query SQLite database for spam/ham messages to be learned
_grom_query_rspamd() {
  local dbfile fields spam_flag folder_id days
  local sql

  # Call with dbfile, query-type, action, days
  # Verify if mandatory arguments are set
  if [[ "$#" -ne 4 ]]; then
    logger -t _grom_query_rspamd "Error: mandatory arguments are missing"; exit 1
  fi

  dbfile="$1"
  # use coalesce for midstring to avoid issues with NULL values
  [[ "$2" = "count" ]] && fields="count(m.message_id)" || fields="m.message_id||'|'||coalesce(m.mid_string,'')"
  if [[ "$3" = "ham" ]]; then
    spam_flag=1; folder_id=0xd
  else
    spam_flag=0; folder_id=0x17
  fi
  days="$4"

  # basic query
  sql="WITH RECURSIVE folder_hierarchy AS
  (SELECT
     f.folder_id,
     f.parent_id
   FROM folders f
   WHERE f.folder_id = $folder_id
   UNION ALL SELECT
     f.folder_id,
     f.parent_id
   FROM folders f
   INNER JOIN folder_hierarchy fh ON f.parent_id = fh.folder_id)
SELECT ${fields}
--select m.message_id, m.mid_string, mp2.propval as spam_flag, datetime(mp1.propval/10000000-11644473600,'unixepoch') as last_modification_time
FROM messages m
-- retrieve the folder hierarchy starting with the user-specified folder
INNER JOIN folder_hierarchy fh ON fh.folder_id = m.parent_fid
-- restrict to email folders (container class=>907214879 must be IPF.Note)
INNER JOIN folder_properties f ON f.folder_id = m.parent_fid
AND f.proptag = 907214879
AND f.propval = 'IPF.Note'
-- restrict to messages with last_modification_time (805830720) older than x days (convert to unix epoch before compare)
INNER JOIN message_properties mp1 ON mp1.message_id = m.message_id
AND mp1.proptag = 805830720
AND (mp1.propval/10000000-11644473600) > unixepoch('now', '-$days days')
-- restrict to message with spam-flag set (1081540619)
LEFT JOIN message_properties mp2 ON mp2.message_id = m.message_id
AND mp2.proptag = 1081540619
WHERE coalesce(mp2.propval, 0) = $spam_flag
ORDER BY m.message_id ASC;"

    printf '%s' "$(sqlite3  -batch -readonly -noheader "$dbfile" "${sql}")"
}


### Internal function to learn ham/spam messages with rspamd
_grom_rspamd_learn() {
  local action user days
  local log_tag mdir dbfile
  local obj msgid midstr
  local exportbin ext
  local cnt=0

  # define function
  _grom_users="${_grom_users:=$(grom_users)}"

  # Call with action, user, days
  # Verify if mandatory arguments are set
  if [[ "$#" -ne 3 ]]; then
    logger -t _grom_rspamd_learn "Error: mandatory arguments are missing"; exit 1
  fi

  if [[ "$_grom_users" =~ $2 ]]; then
    action="$1"
    user="$2"
    days="$3"
    log_tag="grom_rspamd_learn"
    mdir="$(_grom_query_maildir "$user")"
    dbfile="$(_grom_query_maildir "$user")/exmdb/exchange.sqlite3"

    # log message count
    cnt=$(_grom_query_rspamd "$dbfile" "count" "$action" "$days")
    logger -t $log_tag "$user: $cnt $action messages to learn"

    # retrieve message ids
    for obj in $(_grom_query_rspamd "$dbfile" "data" "$action" "$days"); do
      # split obj into message-id and mid-string
      IFS=\| read -r msgid midstr <<< $obj
      
      # push the message to rspamd. if midstr is not empty the file is on disk
      if [[ -n $midstr ]]; then
        # redirect stderr to logger and evaluate stdout
        if ! rspamc learn_$action --header 'Learn-Type: bulk' "$mdir/eml/$midstr" 2> >(logger -t "$log_tag") | grep -q "success = true"; then
          # to log stdout from rspamc use
          #if ! rspamc learn_$action --header 'Learn-Type: bulk' "$mdir/eml/$midstr" 2> >(logger -t "$log_tag") > >(logger -t "$log_tag"); then
          ((cnt=cnt-1))
          printf '%s: Error: Learning %s message %s failed.' "$user" "$action" "$msgid" | logger -t $log_tag
        fi
      else
       # redirect both stderr to logger and evaulate stdout
       if ! rspamc learn_$action --header 'Learn-Type: bulk' <(gromox-exm2eml -u "$user" "$msgid" 2> >(logger -t "$log_tag")) 2> >(logger -t "$log_tag") | grep -q "success = true"; then
          # to log stdout from rspamc use
          #if ! rspamc learn_$action --header 'Learn-Type: bulk' <(gromox-exm2eml -u "$user" "$msgid" 2> >(logger -t "$log_tag")) 2> >(logger -t "$log_tag") > >(logger -t "$log_tag"); then
          ((cnt=cnt-1))
          printf '%s: Error: Learning %s message %s failed.' "$user" "$action" "$msgid" | logger -t "$log_tag"
        fi
      fi
    done
    if [[ $cnt -gt 0 ]]; then
      logger -t $log_tag "$user: $cnt $action messages learned"
    fi
    echo $cnt
  fi
}


### Public function to learn ham/spam messages with rspamd
grom_rspamd_learn() {
  local usage="Usage: $FUNCNAME (ham|spam|all) history_days"
  local action_type history_days
  local cnt=0

  # Verify if mandatory arguments are set
  if [[ "$#" -ne 2 ]]; then
    echo $"$usage"; exit 1
  fi

  # Verify if required binaries exist
  command -v rspamc --commands >/dev/null 2>&1 || { echo >&2 "Error: rspamc is required but not installed."; exit 1; }
  command -v gromox-exm2eml >/dev/null 2>&1 || { echo >&2 "Error: gromox-exm2eml is required but not installed."; exit 1; }
  command -v pgrep >/dev/null 2>&1 || { echo >&2 "Error: pgrep is required but not installed."; exit 1; }

  # Verify if rspamd controller is started
  pgrep -f 'rspamd: controller' >/dev/null 2>&1 || { echo >&2 "Error: rspamd controller service is not started."; exit 1; }

  # Verify action_type
  action_type="$1"
  if ! [[ $action_type = @(ham|spam|all) ]]; then
    # do not echo $usage here as it might be a sub-function
    #echo "Error: Action type '$action_type' is not allowed." >&2; echo $"$usage"; exit 1
    echo "Error: Action type '$action_type' is not allowed." >&2; exit 1
  fi

  # Verify if history days is an integer
  history_days="$2"
  re='^[0-9]+$'
  if ! [[ $history_days =~ $re ]] ; then
    # do not echo $usage here as it might be a sub-function
    #echo "Error: History days '$history_days' is not an integer." >&2; echo $"$usage"; exit 1
    echo "Error: History days '$history_days' is not an integer." >&2; exit 1
  fi

  # Define _grom_users globally
  _grom_users="${_grom_users:=$(grom_users)}"
   
  # Loop over users
  for user in $_grom_users; do
    if [[ "$action_type" = "all" ]]; then
      cnt=$(_grom_rspamd_learn "ham" "$user" "$history_days")
      cnt=$(_grom_rspamd_learn "spam" "$user" "$history_days")
    else
      cnt=$(_grom_rspamd_learn "$action_type" "$user" "$history_days")
    fi
  done
}


### Public function to learn ham messages with rspamd. Kept for backward compatibility
grom_learn_ham() {
  local usage="Usage: $FUNCNAME history_days"

  # Verify if mandatory arguments are set
  if [[ "$#" -ne 1 ]]; then
    echo $"$usage"; exit 1
  fi

  # Call generic function
  grom_rspamd_learn "ham" "$1"
}


### Public function to learn spam messages with rspamd. Kept for backward compatibility
grom_learn_spam() {
  local usage="Usage: $FUNCNAME history_days"

  # Verify if mandatory arguments are set
  if [[ "$#" -ne 1 ]]; then
    echo $"$usage"; exit 1
  fi

  # Call generic function
  grom_rspamd_learn "spam" "$1"
}


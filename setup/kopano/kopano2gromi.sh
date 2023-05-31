#!/usr/bin/env bash
if [[ -z $SRCPASS ]]; then
  echo "Please use 'export SRCPASS' as stated in 'man gromox-kdb2mt'"
  exit 1
fi

SRCHOST="${SRCHOST:-"mail.$(dnsdomainname)"}"
SQLDB="${SQLDB:-kopano}"
SQLUSR="${MQLUSER:-gromox}"
SQLPORT="${SQLPORT:-3306}"
#MOUNTPOINT=$(mktemp -d)
MOUNTPOINT=/tmp/kopno2gromi
LOGDIR=${LOGDIR:-/root/log/}
MBXDIR=/root/export

SSHKEY="/root/.ssh/kopano2gromi"
SSHOPTS='-o "UserKnownHostsFile=/dev/null" \
  -o "StrictHostKeyChecking=no" \
  -o IdentityFile="${SSHKEY}" \
  -o User=root \
  -o Host="${SRCHOST}"'

_spacer() { echo "#######" ; }
_check_ssh_access() {
  if [ ! -e "$SSHKEY" ]; then
    ssh-keygen -f "$SSHKEY" -N ''
    _spacer
    echo "Created a new SSH-Key"
    echo "Please add the Key to the Authorized Keys at"
    echo "root@${SRCHOST}"
    _spacer
    cat "${SSHKEY}.pub"
    _spacer
    exit
  fi
  RET="$(ssh "${SSHOPTS}" whoami)"
  if [[ "$RET" != "root" ]]; then
    _spacer
    echo "Something went wrong. Check the Output:"
    echo "${RET}"
    _spacer
    exit
  else 
    _spacer
    echo "Checking
  fi

  sshfs "$SRCHOST":/var/lib/kopano/attachments "$MOUNTPOINT" -o umask=0000,uid=0
  mkdir -p "${LOGDIR}"

  echoexpimp () {
    echo "$2"
    echo gromox-kdb2mt -s --src-port="${SQLPORT}" --src-host="${SRCHOST}" --src-db="${SQLDB}" --src-at="${MOUNTPOINT}" --src-user="${SQLUSR}" --src-mbox="$1" --without-hidden #|
      echo gromox-mt2exm -u "$2"
    }
    expimp () {
      echo "$2"
      gromox-kdb2mt -s --src-port="${SQLPORT}" --src-host="${SRCHOST}" --src-db="${SQLDB}" --src-at="${MOUNTPOINT}" --src-user="${SQLUSR}" --src-mbox="$1" --without-hidden | gromox-mt2exm -u "$2"
    }
    export () {
      echo "$2"
      gromox-kdb2mt -t -s --src-port="${SQLPORT}" --src-host="${SRCHOST}" --src-db="${SQLDB}" --src-at="${MOUNTPOINT}" --src-user="${SQLUSR}" --src-mbox="$1" --without-hidden > $MBXDIR/"$account".dmp
      echo gromox-mt2exm -u "$2"
    }

#USERLIST=$(grommunio-admin user | awk '{print $2}' |grep -v -E '^admin$|^users$')
USERLIST="$(grommunio-admin user query username |grep -v -E '^(username|admin)$')"
IFS=$'\n' KOPANO_ACCOUNTS=( $(for i in $(ssh ${SRCHOST} kopano-admin -l |tail -n +5|head -n -1|awk '{print $1}') ; do ssh ${SRCHOST} kopano-admin --details "$i" |grep -E 'Username|Emailaddress'| awk '{print $2}'; done) )
for account in $USERLIST; do kopanouser=$(echo "${KOPANO_ACCOUNTS[@]}" | tr ' ' '\n'|tac |awk 'c&&!--c;/'"${account}"'/{c=1}' |tac) 
  #echoexpimp "$kopanouser" "$account" |& tee -a "${LOGDIR}"expimp."${account//[^[:alnum:]]/}".log 
  echoexpimp "$kopanouser" "$account" |& tee -a "${LOGDIR}"expimp."${account//[^[:alnum:]]/}".log 
done
[ -n "${UNMOUNT+x}" ] && umount "$MOUNTPOINT"


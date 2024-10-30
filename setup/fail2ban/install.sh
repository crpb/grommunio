#!/bin/bash
# shellcheck disable=SC2015
#ENFORCE-ROOT
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: $0 Must be run as root, Script terminating" ;exit 7
fi
DESTEMAIL='monitoring@domain.tld'
SENDER='fail2ban-grommunio@domain.tld'
IGNOREIP="127.0.0.1 ::1"

WALTERS_PACKAGE="https://www.hofstaedtler.com/tmp/fail2ban_grommunio_wh.tgz"
JAIL_LOCAL="/etc/fail2ban/jail.local"
SYNC_CONF="/etc/grommunio-sync/grommunio-sync.conf.php"

grep -qF -- "suse" /etc/os-release && (zypper ref && zypper -n up) || (apt-get update && apt-get dist-upgrade --yes)
grep -qF -- "suse" /etc/os-release && (zypper in -y fail2ban) || (apt-get install fail2ban --yes)

wget $WALTERS_PACKAGE -O src.tgz


if [[ -f "$JAIL_LOCAL" ]]; then
  tar xvfz src.tgz -C / --exclude=etc/fail2ban/jail.local
  grep -qF -- "grommmunio" $JAIL_LOCAL && (tar -axf src.tgz etc/fail2ban/jail.local -O | sed -n '/^\[grommunio-web-auth/, $p' >> $JAIL_LOCAL)
else
  tar xfvz src.tgz -C /
fi
#SNIP-FILEBAKDATE
sed -i."$(date +%Y%m%d%H%M)".bak '' $SYNC_CONF
sed -i "s|LOGAUTHFAIL', false|LOGAUTHFAIL', true|g" $SYNC_CONF
#IF NOT EMPTY
if [[ -z "$IGNOREIP" ]]; then
  sed -i -e '/^ignoreip = / s/= .*/= '"$IGNOREIP"'/' $JAIL_LOCAL
fi
sed -i -e '/^destemail = / s/= .*/= '$DESTEMAIL'/' $JAIL_LOCAL
sed -i -e '/^sender = / s/= .*/= '$SENDER'/' $JAIL_LOCAL

systemctl restart fail2ban

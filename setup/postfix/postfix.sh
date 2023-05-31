#!/usr/bin/env bash
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
#cd "$SCRIPT_DIR" || exit
POSTFIXRELAY=$(postconf -h relayhost|cut -d: -f1|tr -d '[]()')
RELAYHOST="${RELAYHOST:-"$(read -r -p "Relayhost: " -i "$POSTFIXRELAY"; echo "$REPLY")"}"
RELAYUSER="${RELAYUSER:-"$(read -r -p "Auth-User: " ; echo "$REPLY")"}"
RELAYPASS="${RELAYPASS:-"$(read -r -p "Auth-Pass: " ; echo "$REPLY")"}"
#switched to dbconf for main.cfg settings. see ../defaults.sh
#while read -r line; do
#  postconf "$line"
#done < "$SCRIPT_DIR"/postdefaults
postconf relayhost=["${RELAYHOST}"]:submission
grep -qF -- "$RELAYHOST" /etc/postfix/sasl_passwd || \
cat << EOF >> /etc/postfix/sasl_passwd
[$RELAYHOST]:submission $RELAYUSER:$RELAYPASS
EOF
postmap /etc/postfix/sasl_passwd
postfix reload

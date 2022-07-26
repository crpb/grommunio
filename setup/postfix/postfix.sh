#!/usr/bin/env bash
RELAYHOST="${RELAYHOST:-smtp.gmx.net}"
RELAYUSER="${RELAYUSER:-my@ema.il}"
RELAYPASS="${RELAYPASS:-INSERTCOINHERE}"
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"
cat postconf | xargs -n 1 postconf 
postconf relayhost=["${RELAYHOST}"]:submission
cat <<EOF >> /etc/postfix/sasl_passwd
[$RELAYHOST]:submission	$RELAYUSER:$RELAYPASS
EOF
postmap /etc/postfix/sasl_passwd
postfix reload

#!/usr/bin/env bash
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# if no postdefaults file exists use this as a fallback
POSTDEFAULTS="smtp_sasl_auth_enable=yes
smtp_sasl_security_options=noanonymous
smtp_sasl_password_maps=lmdb:/etc/postfix/sasl_passwd
smtp_use_tls=yes
smtpd_tls_mandatory_protocols=\!SSLv2,\!SSLv3,\!TLSv1,\!TLSv1.1
smtpd_tls_protocols=\!SSLv2,\!SSLv3,\!TLSv1,\!TLSv1.1"
if test -r "$SCRIPT_DIR/postdefaults" ; then 
	DEFAULTS="$(cat "$SCRIPT_DIR"/postdefaults)" 
else
	DEFAULTS=$POSTDEFAULTS
fi
POSTFIXRELAY="$(postconf -h relayhost|cut -d: -f1|tr -d '[]()')"
RELAYHOST="${RELAYHOST:-"$(read -e -r -p "Relayhost: " -i "$POSTFIXRELAY"; echo "$REPLY")"}"
RELAYUSER="${RELAYUSER:-"$(read -e -r -p "Auth-User: " -i "$(awk '/'"$RELAYHOST"'/ {sub(/:.*/, "", $2);print $2;}' /etc/postfix/sasl_passwd)" ; echo "$REPLY")"}"
RELAYPASS="${RELAYPASS:-"$(read -r -p "Auth-Pass: " ; echo "$REPLY")"}"
SETDEFAULTS="${SETDEFAULS:-"$(read -r -p "Set defaults? (leave empty if not): " ; echo "$REPLY")"}"
if [ ${#SETDEFAULTS} -ne 0 ]; then
#switched to dbconf for main.cfg settings. see ../defaults.sh but it still works if we accept it
while read -r line; do
  postconf "$line"
done <<< "$DEFAULTS"
fi
# check for password-map mechanisms / lmdb on opnsuse
table='lmdb' ; postconf -m |grep -q $table || table='hash'
postconf relayhost=["${RELAYHOST}"]:submission
grep -s -qF -- "$RELAYHOST" /etc/postfix/sasl_passwd || \
cat << EOF >> /etc/postfix/sasl_passwd
[$RELAYHOST]:submission $RELAYUSER:$RELAYPASS
EOF
postmap /etc/postfix/sasl_passwd
# Disable DSN
printf "Set DSN-Food? (leave empty if not): "
read -r accept
if [ ${#accept} -ne 0 ]; then
postconf smtpd_discard_ehlo_keyword_address_maps=cidr:/etc/postfix/esmtp_access
cat << EOF > /etc/postfix/esmtp_access
# Allow DSN requests from local subnet only
$(ip r s p kernel |awk '{print$1;exit}')       silent-discard, dsn
0.0.0.0/0           silent-discard, dsn
::/0                silent-discard, dsn
EOF
fi
postfix reload

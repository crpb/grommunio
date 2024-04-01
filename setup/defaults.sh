#!/bin/sh
#
# This File is a demonstration of dbconf capabilities.
# https://docs.grommunio.com/man/grommunio-admin-dbconf.html
# https://docs.grommunio.com/man/grommunio-admin-mconf.html
#
# shellcheck disable=SC2016 disable=SC2317
#
# gro-ad-exmdb-store sizes.. 2022/08 
mb() { printf "(%f*1024^1)/1\n" "$1"| bc ; }
gb() { printf "(%f*1024^2)/1\n" "$1"| bc ; }
tb() { printf "(%f*1024^3)/1\n" "$1"| bc ; }

#who likes long command-chains?
cmd=$(which grommunio-admin)
dbset () { $cmd dbconf set "$1" "$2" "$3" "$4" ; } 
#Set only LDAP-Auth via mconf
$cmd mconf modify authmgr set authBackendSelection alywas_ldap
#Set Gromox-Mailbox-Defaults - i think those are all possible values
defaults() { dbset grommunio-admin defaults-system "$1" "$2" ; }
defaults user.lang de_DE
defaults user.pop3_imap true
#defaults user.properties.prohibitsendquota    "$(gb 1.4)"
#defaults user.properties.prohibitreceivequota "$(gb 1.6)"
#defaults user.properties.storagequotalimit    "$(gb 1.8)"
defaults domain.maxUser 25
defaults user.smtp false
defaults domain.chat true
defaults user.changePassword false
defaults user.privChat false
defaults user.privVideo false
defaults user.privFiles false
defaults user.privArchive false
defaults user.chat false

#Now we will use dbconf for postfix-settings
# - Setup dbconf-mechanism for postfix
dbset grommunio-dbconf postfix commit_key 'postconf -e $ENTRY'
dbset grommunio-dbconf postfix commit_service 'systemctl reload-or-restart $SERVICE'
#Setup dbconf-postfix-settings
#Helper
postconf() { dbset postfix main.cfg "$1" "$2" ; }
# - Max Message Size - replace mb() to be postfix-compatible
# + https://en.wikipedia.org/wiki/Base64#MIME 
#mb() { printf "((%f*1024^2)*1.37+814)/1\n" "$1"| bc ; }
# or without BC and only AWK
mb() { printf "%d\n" "$1" |awk  '{print $1 * 1024*1024*1.37+815 }' ;}
postconf message_size_limit "$(mb 50)"
# - various SSL/TLS-Settings
postconf smtp_sasl_auth_enable yes
postconf smtp_sasl_security_options noanonymous
postconf smtp_use_tls yes
postconf smtpd_tls_mandatory_protocols '!SSLv2,!SSLv3,!TLSv1,!TLSv1.1'
postconf smtpd_tls_protocols '!SSLv2,!SSLv3,!TLSv1,!TLSv1.1'
# - Relay-Host
table='lmdb' ; postconf -m |grep -q $table || table='hash'
postconf smtp_sasl_password_maps "${table}:/etc/postfix/sasl_passwd"
# the rest via ./postfix/postfix.sh for now. or just from you config-mgmt :P

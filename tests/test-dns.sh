#!/bin/bash
# vim:ft=sh ts=2 sts=2 sw=2 et
# Copyright © 2023 Christopher Bock <christopher@bocki.com>
# SPDX-License-Identifier: MIT
#
# BIND9-TEMPLATE
# vim:filetype=bindzone
#                        TXT              "mailconf=https://grommunio-host.domain.tld/.well-known/autoconfig/mail/config-v1.1.xml"
# $ORIGIN domain.tld.
# _autodiscover._tcp IN  SRV    0  1  443 grommunio-host.domain.tld.
# _caldav._tcp       IN  SRV    0  0  0   .
# _caldavs._tcp          TXT              "path=/dav/calendars"
# _caldavs._tcp      IN  SRV    0  1  443 grommunio-host.domain.tld.
# _carddav._tcp      IN  SRV    0  0  0   .
# _carddavs._tcp         TXT              "path=/dav/addressbooks"
# _carddavs._tcp     IN  SRV    0  1  443 grommunio-host.domain.tld.
# _imap._tcp         IN  SRV    10 1  143 grommunio-host.domain.tld.
# _imaps._tcp        IN  SRV    0  1  993 grommunio-host.domain.tld.
# _pop3._tcp         IN  SRV    10 1  110 grommunio-host.domain.tld.
# _pop3s._tcp        IN  SRV    10 1  995 grommunio-host.domain.tld.
# _sieve._tcp        IN  SRV    0  0  0   .
# ;_sieve._tcp        IN  SRV 0 1 4190  grommunio-host.domain.tld.
# _smtp._tcp         IN  SRV    0  1  25  grommunio-host.domain.tld.
# _smtps._tcp        IN  SRV    0  0  0   .
# ;_smtps._tcp        IN  SRV 0 1 465 grommunio-host.domain.tld.
# _submission._tcp   IN  SRV    0  1  587 grommunio-host.domain.tld.
# autodiscover       IN  CNAME            grommunio-host.domain.tld.

DOMAIN=$1
NS=${2-resolver1.opendns.com}
NS="@${NS}"
test -z "$1" && { echo "Usage: $0 domain.tld [dns-server]" ; exit 1 ; }
SRV=(autodiscover caldav caldavs carddav carddavs imap imaps pop3 pop3s smtp smtps sieve submission)
TXT=( caldav caldavs carddav carddavs )
DIG=$(command -v dig || { echo "Command dig not found" ; exit 1 ; })
# Check for _tcp
for ENT in "${SRV[@]}"; do
  NAME="_${ENT}._tcp.${DOMAIN}"
  echo -e "Testing \033[0;32m$NAME\033[0m"
  RET="$($DIG +short +timeout=1 SRV "$NAME" $NS || echo "Error: $NAME")"
  if [ ${#RET} -gt 1 ]; then
    printf '\t%s\n' "$RET"
  else
    echo -e "\t\033[0;35mNothing found\033[0m"
  fi
  unset RET
done
# Check for TXT
for ENT in "${TXT[@]}"; do
  NAME="_${ENT}._tcp.${DOMAIN}"
  echo -e "Testing \033[0;32m$NAME\033[0m"
  RET="$($DIG +short +timeout=1 TXT "$NAME" $NS || echo "Error: $NAME")"
  if [ ${#RET} -gt 1 ]; then
    printf '\t%s\n' "$RET"
  else
    echo -e "\t\033[0;35mNothing found\033[0m"
  fi
  unset RET
done
# Check for mailconf
echo -e "Testing \033[0;32m$DOMAIN\033[0m mailconf="
RET="$($DIG +short +timeout=1 TXT "$DOMAIN" $NS |grep mailconf)"
echo -e "\t${RET}"

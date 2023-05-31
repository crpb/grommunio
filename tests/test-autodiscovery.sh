#!/bin/bash
dscli=$(which gromox-dscli)
[ -z "${EMAIL+x}" ] && \
  printf "\nexport EMAIL=\"email@addre.ss\" to hide this prompt.\n\n"
EMAIL="${EMAIL:-"$(read -r -p "EMAIL: " ; echo "$REPLY")"}"
[ -z "${PASS+x}" ] && \
  printf "\n export PASS=\"SECRET\" to hide this prompt.\n\n"
PASS="${PASS:-"$(read -r -s -p "PASS: " ; echo "$REPLY")"}"
echo
export PASS
DOMAIN="${EMAIL##*@}"
HOSTS="$DOMAIN www.$DOMAIN autodiscover.$DOMAIN"
SRVDOM="_autodiscover._tcp.$DOMAIN"
if command -v /usr/lib/apt/apt-helper >/dev/null; then
  SRV=$(/usr/lib/apt/apt-helper srv-lookup "$SRVDOM" 2>/dev/null | \
    tail -n 1 | awk '{print $1}') || SRV=""
else
  SRV=$(host -t SRV "$SRVDOM" | \
    awk '{print $NF}' | sed 's/\.$//')
fi
HOSTS="${HOSTS} $SRV"
printf "Possible Hosts: %s\n\n" "$HOSTS"
for host in $HOSTS; do
  printf "Trying: %s\n\n" "$host"
  $dscli -e "$EMAIL" -h "$host" 2>/dev/null | \
    sed -e 's/</\n</g' | \
    grep -Po '(?=<[^\/]).*(?=$)' | \
    sed 's/^<//g;s/>/: /g;/:\s$/d' | \
    sed -n '/AutoDiscoverSMTPAddress/,$p'
done

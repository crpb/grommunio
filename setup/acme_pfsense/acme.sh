#!/usr/bin/env bash
#===============================================================================
#
#          FILE: acme2server.sh
# 
#         USAGE: ./acme2server.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: DNS-Eintrag gate.DOMAIN.NAME muss gesetzt sein!!!-
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Christopher Bock (cb), christopher@bocki.com
#  ORGANIZATION: 
#       CREATED: 09/02/2017 06:26:16 PM
#      REVISION:  --1xyz...
#===============================================================================

#set -o nounset                              # Treat unset variables as an error

#Name of Certificate on pfSense: Services / Acme / Certificates
readonly CERT_NAME='wildcard'
#Default Hostname of pfSense
readonly SSH_HOST="gate"
#Download-User on pfSense
readonly SSH_USER="acme"
readonly SCP_OPTS="-q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /root/.ssh/acme"
readonly BASEDIR="$(dirname $0)"
#Check for ROOT...
if [ ! $( id -u ) -eq 0 ]; then
echo "ERROR: $0 Must be run as root, Script terminating" ;exit 7
fi
#Erstelle SSH-Key wenn nicht vorhanden und Drucke ihn aus.
if [ ! -e /root/.ssh/acme ]; then
ssh-keygen -f /root/.ssh/acme -N ''
echo "-----------------------------------------------"
echo "Unter Services/ACME/Settings/General settings "
echo "Write Certificates aktivieren                 "
echo "-----------------------------------------------"
echo "Bitte Key als User acme auf pfSense hinterlegen"
echo "-----------------------------------------------"
cat /root/.ssh/acme.pub
echo "-----------------------------------------------"
echo
echo "Berechtigung für den Benutzer:"
echo "User - System: Copy files (scp)"
echo
exit
fi

#DNSDOMAIN?!!?...
assign () { 
	eval "$1=\$(cat; echo .); $1=\${$1%.}"
}

assign dnsdomain < <(grep -e  ^domain /etc/resolv.conf  || grep ^search /etc/resolv.conf)
DNS=${dnsdomain:7}
#Turn on extended globbing
shopt -s extglob
#Trim leading and trailing whitespace from a variable
DNS=${DNS##+([[:space:]])}; DNS=${DNS%%+([[:space:]])}
#Turn off extended globbing
shopt -u extglob

readonly SCP_STR=${SSH_USER}@${SSH_HOST}.${DNS}
#TOUCH TEMP...
CERT_OUT=$(mktemp /tmp/output.XXXXXXXXXX) || { echo "Failed to create temp file"; exit 1; }
#TEST CONNECTION
scp ${SCP_OPTS} ${SCP_STR}:/etc/version /tmp/
if [ "$?" -eq "1" ];
then
echo "Bitte Key als User acme auf pfSense hinterlegen"
echo "Und nur SCP-Rechte geben."
echo "-----------------------------------------------"
cat /root/.ssh/acme.pub
echo "-----------------------------------------------"
echo
exit 1
fi

#FOLDER /etc/ssl/acme/dns.domain.name/
readonly CERT_FILE=/etc/ssl/acme/$CERT_NAME.all.pem
readonly CERT_DIR="$(dirname "${CERT_FILE}")"

#TRY DOWNLOAD OF CERTNAME.ALL.PEM
scp ${SCP_OPTS} ${SCP_STR}:/conf/acme/${CERT_NAME}.all.pem ${CERT_OUT} || \
{ echo "Failed to Retrieve File"; exit 1; }

#COMPARE WITH CURRENTLY INSTALLED CERTIFICATE / CREATE FOLDER IF NOT EXISTENT / COPY NEW CERTIFICATE IF NOT EXISTENT/DIFFERENT
cmp --silent ${CERT_FILE} ${CERT_OUT} || \
mkdir -p `dirname ${CERT_FILE}` && \
cp $CERT_OUT $CERT_FILE && \
#FAULHEIT....
scp ${SCP_OPTS} $SCP_STR:/conf/acme/${CERT_NAME}.crt $CERT_DIR/cert.pem && \
scp ${SCP_OPTS} $SCP_STR:/conf/acme/${CERT_NAME}.ca $CERT_DIR/ca.pem && \
scp ${SCP_OPTS} $SCP_STR:/conf/acme/${CERT_NAME}.key $CERT_DIR/key.pem && \
scp ${SCP_OPTS} $SCP_STR:/conf/acme/${CERT_NAME}.fullchain $CERT_DIR/fullchain.pem || \
{ echo "Failed to Retrieve Files"; exit 1; }


#alias -g anix='apache2ctl configtest && apache2ctl restart'
#anix
#alias -g renix='nginx -t  && nginx -s reload'
#renix

#GROMMUNIO-SSL-SERVICES.... grommunio-admin-api wohl net unbedingt wie es scheint.. erreichbar via nginx..
systemctl list-units |grep -E 'postfix|http|imap|pop|admin|nginx' |grep service |cut -d' ' -f 3 |xargs -n 1 systemctl restart 

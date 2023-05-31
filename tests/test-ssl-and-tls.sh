#!/bin/bash
shopt -s expand_aliases
alias sslscan-short='sslscan --no-cipher-details --no-ciphersuites --no-compression --no-fallback --no-groups --no-heartbleed --no-renegotiation'
alias sslscan-ocsp='sslscan --no-cipher-details --no-ciphersuites --no-compression --no-fallback --no-groups --no-heartbleed --no-renegotiation --ocsp'
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Check if binary exist
is_binary_exist() {
	local binary=$1
	command -v "$binary" &> /dev/null
	return $?
}
if ! is_binary_exist sslscan; then
	hash -p "${SCRIPT_DIR}/sslscan" sslscan
fi
if [ -z "${SPC}$1" ]; then
HOSTNAME="$(hostname -f)"
else
HOSTNAME="$1"
fi
SPC="################################################################################\n"
printf "${SPC}HTTPS-WEB\n${SPC}"
sslscan-ocsp $HOSTNAME
printf "${SPC}HTTPS-ADMIN\n${SPC}"
sslscan-ocsp $HOSTNAME:8443
printf "${SPC}SMTP-TLS\n${SPC}"
sslscan-short --starttls-smtp $HOSTNAME:25
printf "${SPC}SMTP-SSL\n${SPC}"
sslscan-short $HOSTNAME:465
printf "${SPC}SUBMISSION-TLS\n${SPC}"
sslscan-short --starttls-smtp $HOSTNAME:587
printf "${SPC}POP-TLS\n${SPC}"
sslscan-short --starttls-pop3 $HOSTNAME:110
printf "${SPC}POP-SSL\n${SPC}"
sslscan-short $HOSTNAME:995
printf "${SPC}IMAP-TLS\n${SPC}"
sslscan-short --starttls-imap $HOSTNAME:143
printf "${SPC}IMAP-SSL\n${SPC}"
sslscan-short $HOSTNAME:993

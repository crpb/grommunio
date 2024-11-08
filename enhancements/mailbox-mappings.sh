#!/bin/bash
set -e
set -x

# retrieve mailbox folders, usually /var/lib/gromox/{user,domain}
domainPrefix=$(grommunio-admin config get options.domainPrefix)
userPrefix=$(grommunio-admin config get options.userPrefix)

# retrieve all configured domains
domaindata="$(grommunio-admin domain query --format=csv --separator=';' homedir ID domainname | grep "^${domainPrefix}")"
userdata="$(grommunio-admin user query --format=csv --separator=';' maildir ID username domainID | grep "^${userPrefix}")"
#
# grommunio-admin domain query --format json-structured ID orgID domainname activeUsers address adminName chat chatID displayname domainStatus endDay homedir homeserverID inactiveUsers maxUser tel title virtualUsers
# grommunio-admin org query --format json-structured ID name domainCount description
# grommunio-admin user query --format json-structured ID aliases changePassword chat chatAdmin domainID forward homeserverID lang ldapID maildir pop3_imap privArchive privChat privFiles privVideo publicAddress smtp status username
#
for domain in ${domaindata[@]}; do
  domainID="$(awk -F';' '{print $2}' <<< "$domain")"
  domainname="$(awk -F';' '{print $3}' <<< "$domain")"
  homedir="$(awk -F';' '{print $1}' <<< "$domain")"
  users="$(awk -F';' '$4=='$domainID'' <<< "$userdata")"
  for user in $users; do
    read maildir username <<< $(awk -F';' '{print $1, $3}' <<< "$user")
  done
done

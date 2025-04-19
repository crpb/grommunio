#!/usr/bin/env bash

cleanup() { rm -rf "$COOKIE" ; }
trap cleanup EXIT

COOKIE=$(mktemp -t adminapi-XXXXXX)
if test -z $GROMHOST; then
  printf 'export GROMHOST=grommunio.foo.tld to skip this question.\n\n'
  read -p "Enter Hostname: " -r GROMHOST
fi
if test -z $APIPASS; then
  printf 'export ADMINPASS=foo to skip this question.\n\n'
  read -p "Enter Adminpassword: " -r APIPASS
fi
AUTHRESPONSE=$(curl -s https://$GROMHOST:8443/api/v1/login -d "user=admin&pass=$APIPASS")
JWT=$(echo "$AUTHRESPONSE" |jq -r .grommunioAuthJwt)
CSRF=$(echo "$AUTHRESPONSE" |jq -r .csrf)
echo -e "\n\n$JWT\n\n$CSRF\n\n"
read -r -d '' CURLOPTS << EOOPTS
  --location --silent
  -H 'X-CSRF-TOKEN=$CSRF'
  -H 'Cookie:grommunioAuthJwt=$JWT'
  -H 'X-AUTH-TOKEN:grommunioAuthJwt=$JWT'
  -H 'X-AUTH-TOKEN:$JWT'
  -H 'TOKEN:$JWT'
  -H 'grommunioAuthJwt=$JWT'
EOOPTS

curl -v $CURLOPTS https://$GROMHOST:8443/api/v1/system/orgs


  # -H 'Content-Type:application/json'
  # -H 'Accept:application/json'
  #-H \"X-Auth-Token: $JWT\" \
  #-H \"X-CSRFToken: $CSRF\" \
  #-H \"Cookie: csrftoken=$CSRF\" \

 # -H 'Cookie: csrftoken=$CSRF'
 # -H 'Token:$JWT'
 # -H 'X-Auth-Token:$JWT'
  # -d \"user=admin&pass=$APIPASS\" \

#!/usr/bin/env bash

# https://github.com/grommunio/admin-api/issues/33#issuecomment-2467681926
# > This can be achieved by creating a user with `SystemAdminRO` permissions and then generating an access token via `grommunio-admin user login <username> --nopass --token`.
# > I can also add an explicit expiry parameter to the CLI call if needed, otherwise the global default for login tokens applies (`security.jwtExpiresAfter` configuration).
# https://github.com/grommunio/admin-api/issues/33#issuecomment-3442046597
# > You can now use --no-maildir to create a user without a mailbox.
#
# So to create a api-user we just do
# `grommunio-admin user create --no-maildir someapiapp@host.tld`
# `grommunio-admin password someapiapp@host.tld` # this is still needed
# `grommunio-admin user login someapiapp@host.tld --nopass --token`
# Still waiting for better parsable output for the last one.
# https://github.com/grommunio/admin-api/issues/66


if test -z "$GROMHOST"; then
  printf 'export GROMHOST=grommunio.foo.tld to skip this question.\n\n'
  read -p "Enter Hostname: " -r GROMHOST
fi
if test -z "$APIPASS"; then
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

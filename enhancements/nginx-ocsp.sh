#!/bin/bash
#changed to a file not in /etc/ssl/certs as zypper deletes them with updates?!
DHPARAM=/etc/nginx/dhparam.pem
# shellcheck disable=2207
IFS=$'\n' SSLPARAMS=($(find /usr/share/grom* -iname '*ssl*params.conf'))
# activate dhparam
if [ ! -f $DHPARAM ]; then
  # -dsaparam is faster and should be _safe_ enough
  openssl dhparam -dsaparam -out $DHPARAM 4096
  chmod 640 $DHPARAM
fi

# SPLIT CERT-CHAIN
FULLCHAIN=$(</etc/grommunio-common/ssl/server-bundle.pem)
CERTIFICATE="${FULLCHAIN%%-----END CERTIFICATE-----*}-----END CERTIFICATE-----"
CHAIN=$(echo -e "${FULLCHAIN#*-----END CERTIFICATE-----}" | sed '/./,$!d')

# Check if got an ocsp staple in our certificate
check_ocsp () {
  openssl ocsp -issuer <(echo "$CHAIN") -cert <(echo "$CERTIFICATE") -text \
    -url "$(openssl x509 -noout -ocsp_uri -in <(echo "$CERTIFICATE"))" |& \
    grep -q "Response verify OK"
}

for conf in "${SSLPARAMS[@]:-}"; do
  sed -i -e 's/^\# ssl_dhparam \/etc/ssl_dhparam \/etc/g' \
    -e "s|/etc/ssl/certs/dhparam.pem|$DHPARAM|g" "${conf}"
  if check_ocsp; then
    if ! grep -q "^ssl_stapling" "${conf}" ; then
      cat << 'EOF' >> "${conf}"
ssl_stapling on;
ssl_stapling_verify on;
EOF
    fi
  fi
done
systemctl restart nginx.service

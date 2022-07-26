#!/bin/bash

# activate dhparam
if [ ! -f /etc/ssl/certs/dhparam.pem ]; then
  ## speed things up a bit in case we are missing entropy
  #if (( $(cat /proc/sys/kernel/random/entropy_avail) < 1000 )); then
  #  zypper --non-interactive install haveged
  #  systemctl start haveged
  #fi
  openssl dhparam -dsaparam -out /etc/ssl/certs/dhparam.pem 4096
  chmod 640 /etc/ssl/certs/dhparam.pem
  #systemctl stop haveged >/dev/null 2>&1
  #zypper --non-interactive remove haveged >/dev/null 2>&1
fi
sed -i 's/^\# ssl_dhparam \/etc/ssl_dhparam \/etc/g' \
/usr/share/grommunio-common/nginx/ssl_params.conf \
/usr/share/grommunio-admin-common/nginx-ssl-params.conf

# SPLIT CERT-CHAIN
FULLCHAIN=$(</etc/grommunio-common/ssl/server-bundle.pem)
CERTIFICATE="${FULLCHAIN%%-----END CERTIFICATE-----*}-----END CERTIFICATE-----"
CHAIN=$(echo -e "${FULLCHAIN#*-----END CERTIFICATE-----}" | sed '/./,$!d')

# Check if got an ocsp staple in our certificate
check_ocsp () {
  openssl ocsp -issuer <(echo "$CHAIN") -cert <(echo "$CERTIFICATE") -text -url "$(openssl x509 -noout -ocsp_uri -in <(echo "$CERTIFICATE"))" |& grep -q "Response verify OK"
}

#ADMIN
if check_ocsp; then
  if ! grep -q "ssl_stapling" /usr/share/grommunio-admin-common/nginx-ssl-params.conf ; then
    cat << EOF >> /usr/share/grommunio-admin-common/nginx-ssl-params.conf
ssl_stapling on;
ssl_stapling_verify on;
EOF
  fi
fi

#WEBAPP
if check_ocsp; then
  if ! grep -q "ssl_stapling" /usr/share/grommunio-common/nginx/ssl_params.conf ; then
    cat << EOF >> /usr/share/grommunio-common/nginx/ssl_params.conf
ssl_stapling on;
ssl_stapling_verify on;
EOF
  fi
fi

nginx -t && nginx -s reload


#!/usr/bin/env bash
# vim: ts=2 sw=2 sts=2 et
# Copyright © 2023 Christopher Bock <christopher@bocki.com>
# SPDX-License-Identifier: MIT

echo "Number of Packages: $(dpkg -l |grep '^ii' |wc -l)"

apt-get update >/dev/null
apt-get install wget xz-utils --yes

rpms="grommunio-admin-common grommunio-common"
_get_rpm_url() {
  if [[ "$#" -eq 1 ]]; then
    local repo subf flst
    repo="https://download.grommunio.com" #/community/openSUSE_Leap_15.4/
    subf="community/openSUSE_Leap_15.4/"
    flst=$(wget -q -qO- "$repo/$subf" |grep -Po '(?<=href=")[^"]*(?=")' |cut -d/ -f4-)
    arch=$(uname -m)
    echo "$repo/$subf/$(echo "$(grep -E "$1-[0-9]" <<< "$flst")"|grep -E "$arch|noarch" |tail -n1)"
  fi
}
# Keep list of packages to cleanup behind ourself
PKGS=()
PKGS="(${PKGS[@]} $(apt-get --assume-no --download-only --mark-auto -u install alien | sed '0,/The following NEW packages will be installed/d;/^[^ ]/,$d'))"
apt-get --yes --mark-auto -u install alien >/dev/null
TMPCONV=$(mktemp -d --suffix=rpmconv)
cd $TMPCONV || exit
echo "Converting RPMs to DEBs"
for rpm in $rpms; do wget -q -P $TMPCONV -nc "$(_get_rpm_url "$rpm")"; done
alien $TMPCONV/*.rpm >/dev/null |& grep -v warning

echo "Setting up Build-Environment"
TMPBLD=$(mktemp -d --suffix=nginx)
cd $TMPBLD || exit
chmod 775 $TMPBLD
PKGS="(${PKGS[@]} $(apt-get --assume-no --download-only --mark-auto -u build-dep nginx | sed '0,/The following NEW packages will be installed/d;/^[^ ]/,$d'))"
apt-get --yes --mark-auto -u build-dep nginx >/dev/null
apt-get -o APT::Sandbox::Seccomp=0 source nginx >/dev/null

echo "Building nginx module: traffic-status"
cd $TMPBLD || exit
[[ ! -d module-vts ]] && git clone https://github.com/vozlt/nginx-module-vts.git module-vts
cd nginx-*/ || exit
OPTS="$(echo $(nginx -V |& grep configure\ arguments |sed 's/.*prefix/--prefix/') --add-dynamic-module=../module-vts/)"
./configure $OPTS >/dev/null
make modules >/dev/null
LIBDIR=/usr/local/lib/nginx/modules
mkdir -p $LIBDIR
cp objs/ngx_http_vhost_traffic_status_module.so $LIBDIR/
echo  "load_module $LIBDIR/ngx_http_vhost_traffic_status_module.so;" > /etc/nginx/modules-available/90-mod-vhost-traffic-status.conf
ln -f -s /etc/nginx/modules-available/90-mod-vhost-traffic-status.conf /etc/nginx/modules-enabled/

if grep -q bookworm /etc/os-release; then
  apt-get install libnginx-mod-http-brotli-static libnginx-mod-http-brotli-filter --yes
else
  echo "Building nginx module: brotli"
  cd $TMPBLD || exit
  [[ ! -d ngx_brotli ]] && git clone https://github.com/google/ngx_brotli.git
  cd nginx-*/ || exit
  OPTS="$(echo $(nginx -V |& grep configure\ arguments |sed 's/.*prefix/--prefix/') --add-dynamic-module=../ngx_brotli/)"
  ./configure $OPTS >/dev/null
  make modules >/dev/null
  cp objs/ngx_http_brotli_*.so $LIBDIR/
  cat << EOF > /etc/nginx/modules-available/90-mod-brotli.conf
load_module $LIBDIR/ngx_http_brotli_filter_module.so;
load_module $LIBDIR/ngx_http_brotli_static_module.so;
EOF
  ln -f -s /etc/nginx/modules-available/90-mod-brotli.conf /etc/nginx/modules-enabled/
fi

echo "Extracting and installing configuration-files"
cd $TMPCONV || exit
TMPDIR=$(mktemp -d)
ar -x "$(find $TMPCONV/grommunio-common*deb)" data.tar.xz --output="$TMPDIR"
tar Jft "$TMPDIR/data.tar.xz" |grep -E '(traffic_status_params|brotli)' |xargs -n 1 tar Jfx "$TMPDIR/data.tar.xz" -C /

TMPDIR=$(mktemp -d)
ar -x "$(find $TMPCONV/grommunio-admin-common*deb)" data.tar.xz --output="$TMPDIR"
tar Jft "$TMPDIR/data.tar.xz" |grep -E 'traffic-' |xargs -n 1 tar Jfx "$TMPDIR/data.tar.xz" -C /

echo "Restarting NGINX"
nginx -t && systemctl restart nginx.service

echo "Removing temporary packages"
apt-get --yes --purge --autoremove remove ${PKGS[@]} >/dev/null
echo "Number of Packages: $(dpkg -l |grep '^ii' |wc -l)"
exit 0

#!/bin/bash -
#===============================================================================
#
#          FILE: build.sh
#
#         USAGE: ./build.sh
#
#   DESCRIPTION: 
#
#       OPTIONS: ---
#  REQUIREMENTS: MANY
#          BUGS: ALL OF THEM
#         NOTES: BROKEN BY DESIGN
#        AUTHOR: Christopher Bock, christopher@bocki.com 
#  ORGANIZATION: 
#       CREATED: 11/16/2022 10:10:15 AM
#      REVISION: 0815
#===============================================================================

set -o nounset                                  # Treat unset variables as an error

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if test ! -d "${SCRIPT_DIR}/context/gromox"; then
  git clone https://github.com/grommunio/gromox.git "${SCRIPT_DIR}/context/gromox"
else
  cd "${SCRIPT_DIR}/context/gromox"; git pull; cd "${SCRIPT_DIR}"
fi
if command -v podman-compose >/dev/null; then
  podman-compose build --pull
  podman pod create --label gromox
else
  docker-compose build
fi

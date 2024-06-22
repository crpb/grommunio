#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
install -o root -g root -m 0755 $SCRIPT_DIR/grommunio-ham-run.sh /usr/local/sbin/
install -o root -g root -m 0644 $SCRIPT_DIR/grommunio-ham-run.service /etc/systemd/system/
install -o root -g root -m 0644 $SCRIPT_DIR/grommunio-ham-run.timer /etc/systemd/system/
systemctl daemon-reload
systemctl --no-pager enable grommunio-ham-run.timer

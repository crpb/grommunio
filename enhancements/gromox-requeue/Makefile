install:
	install -v -o root -g root -m 0755 gromox-requeue /usr/local/sbin/
	install -v -o root -g root -m 0644 gromox-requeue.service \
		/etc/systemd/system/
	install -v -o root -g root -m 0644 gromox-requeue.timer \
		/etc/systemd/system/
	systemctl daemon-reload
	systemctl --no-pager --now enable gromox-requeue.service \
		gromox-requeue.timer
uninstall:
	systemctl --no-pager --now disable gromox-requeue.service \
		gromox-requeue.timer
	rm -vf /usr/local/sbin/gromox-requeue
	rm -vf /etc/systemd/system/gromox-requeue.service
	rm -vf /etc/systemd/system/gromox-requeue.timer
	systemctl daemon-reload

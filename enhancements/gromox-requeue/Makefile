install:
	install -v -o root -g root -m 0755 gromox-requeue /usr/local/sbin/
	install -v -o root -g root -m 0644 gromox-requeue.service \
		/etc/systemd/system/
	install -v -o root -g root -m 0644 gromox-requeue.path \
		/etc/systemd/system/
	systemctl daemon-reload
	systemctl --no-pager --now enable gromox-requeue.service \
		gromox-requeue.path
uninstall:
	systemctl --no-pager --now disable gromox-requeue.service \
		gromox-requeue.path
	rm -vf /usr/local/sbin/gromox-requeue
	rm -vf /etc/systemd/system/gromox-requeue.service
	rm -vf /etc/systemd/system/gromox-requeue.path
	systemctl daemon-reload
uninstall_timer:
	systemctl --no-pager --now disable gromox-requeue.timer
	rm -vf /etc/systemd/system/gromox-requeue.timer
	systemctl daemon-reload

install:
	install -v -o root -g root -m 0755 grommunio-spam-run.sh /usr/local/sbin/
	install -v -o root -g root -m 0644 -D grommunio-spam-run.override \
		/etc/systemd/system/grommunio-spam-run.service.d/override.conf 
	install -v -o root -g root -m 0755 grommunio-ham-run.sh /usr/local/sbin/
	install -v -o root -g root -m 0644 grommunio-ham-run.service /etc/systemd/system/
	install -v -o root -g root -m 0644 grommunio-ham-run.timer /etc/systemd/system/
	install -v -o grommunio -g gromoxcf -m 0640 spamrun.cfg /etc/gromox/
	systemctl daemon-reload
	systemctl --no-pager --now enable \
		grommunio-ham-run.service \
		grommunio-ham-run.timer \
		grommunio-spam-run.service \
		grommunio-spam-run.timer
uninstall:
	systemctl --no-pager --now disable \
		grommunio-ham-run.service \
		grommunio-ham-run.timer \
		grommunio-spam-run.service \
		grommunio-spam-run.timer
	rm -vf /etc/systemd/system/grommunio-ham-run.service
	rm -vf /etc/systemd/system/grommunio-ham-run.timer
	rm -vf /usr/local/sbin/grommunio-ham-run.sh
	systemcel daemon-reload

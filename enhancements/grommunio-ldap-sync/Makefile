install:
	install -v -o root -g root -m 0755 grommunio-ldap-sync /usr/local/sbin/
	install -v -o root -g root -m 0644 grommunio-ldap-sync.service \
		/etc/systemd/system/
	install -v -o root -g root -m 0644 grommunio-ldap-sync.timer \
		/etc/systemd/system/
	systemctl daemon-reload
	systemctl --no-pager --now enable \
		grommunio-ldap-sync.service grommunio-ldap-sync.timer
uninstall:
	systemctl --no-pager --now disable \
		grommunio-ldap-sync.service grommunio-ldap-sync.timer
	rm -vf /etc/systemd/system/grommunio-ldap-sync.service
	rm -vf /etc/systemd/system/grommunio-ldap-sync.timer
	systemcel daemon-reload

# [kopano2grommunio.sh](https://github.com/grommunio/gromox/blob/master/tools/kopano2grommunio.sh)

### Snippets you could use to finally be lazy

#### on the old kopano-host

```
# vim: filetype=bash
#-->SSH->KOPANO-SERVER
# allow ssh as root
sudo -i
# shellcheck disable=2174
mkdir -p -m 0700 ~/.ssh/
curl -L https://host.tld/key.pub >> ~/.ssh/authorized_keys
sed -i 's/^.*RootLogin.*$/PermitRootLogin=yes/g' /etc/ssh/sshd_config
systemctl restart ssh
# allow remote mysql
PASSWD=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c"${1:-12}";echo;)
MYSQLDFILE=$(grep -iRl bind-address /etc/mysql/  |grep -v dpkg-dist)
sed -i 's/bind-address.*/bind-address = 0.0.0.0/g' "${MYSQLDFILE}"
sed -i 's/mysqlx-bind-.*/^#mysqlx-bind-address = 127.0.0.1/g' "${MYSQLDFILE}"
systemctl restart mysql
#... if something is faulty this will break...
#echo "CREATE USER 'gromox'@'gromi."$(dnsdomainname)"' IDENTIFIED BY '"$PASSWD"';" |mysql
#echo "GRANT SELECT ON "$DATABASE".* TO 'gromox'@'gromi."$(dnsdomainname)"';" |mysql
#IP=$(host gromi.$(dnsdomainname) |cut -d' ' -f4)
#echo "GRANT SELECT ON "$DATABASE".* TO 'gromox'@"$IP";" |mysql
#...
# Do we need a Password?
if ! mysql<<<"exit"&>/dev/null; then
 echo -e "\n export MYSQL_PWD=\"SECRET\" to hide this prompt.\n"
 MYSQL_PWD="${MYSQL_PWD:-"$(read -r -s -p "MYSQLPASS: " ; echo "$REPLY")"}"
 export MYSQL_PWD && echo
fi
DATABASE=$(mysql<<<"SHOW DATABASES"|sort|grep -E 'kopano|zarafa'|head -n1)
# Yes! I'm to lazy to combine those commands into less...
if mysql -V |grep -qi 'maria'; then
  mysql << MARIA
CREATE USER
  'gromox'@'%'
IDENTIFIED BY
  "${PASSWD}";
GRANT SELECT
  ON "${DATABASE}".*
  TO 'gromox'@'%';
FLUSH PRIVILEGES;
MARIA
else
  mysql << MYSQL
CREATE USER
  'gromox'@'%'
IDENTIFIED WITH
mysql_native_password BY
  "${PASSWD}";
GRANT SELECT
  ON "${DATABASE}".*
  TO 'gromox'@'%';
FLUSH PRIVILEGES;
MYSQL
fi
echo "${PASSWD}" >~/.mysql_pass_gromox
cat << REM
#######################
#REMEMBER: $PASSWD
#######################
REM
```

#### On our new grommunio-host

> ForwardAgent=yes

```
#apt-get install --yes sshfs
zypper --non-interactive install --auto-agree-with-licenses sshfs --yes
mkdir -p ~/import
wget -P ~/bin/ https://raw.githubusercontent.com/grommunio/gromox/master/tools/kopano2grommunio.sh
SCRIPT="/root/bin/kopano2grommunio.sh"
chmod +x $SCRIPT
sed -i 's/kopanodb.example.com/mail.'$(dnsdomainname)'/g' $SCRIPT
sed -i 's|/srv/kopano/attachments|/var/lib/kopano/attachments|g' $SCRIPT
sed 's/^CreateGrommunioMailbox=.*/CreateGrommunioMailbox=0/' $SCRIPT
sed -i 's/GrommunioUser/gromox/g' $SCRIPT
sed -i 's/KopanoUserPWD/#KopanoUserPWD/g' $SCRIPT
sed -i 's|/tmp/|/root/import/|g' $SCRIPT
MYSQLPASS=$(ssh root@mail.$(dnsdomainname) cat ~/.mysql_pass_gromox)
sed -i 's/Secret_mysql_Password/'$MYSQLPASS'/g' $SCRIPT
sed -i '/KopanoMySqlPWD=""/d' $SCRIPT
ssh -t root@mail.$(dnsdomainname) -- "for user in \$(kopano-admin -l |tail -n +5|head -n -1|awk '{print \$1}'); do EMAIL=\$(kopano-admin --details \${user} | sed -n '/address\:\s/ p'|awk '{print \$NF}'); GUID=\$(kopano-admin --details \${user} | sed -n '/GUID\:\s/ p'|awk '{print \$NF}');echo "\$EMAIL,\$GUID,1" ;done" |tee -a ~/import/k2g_list.txt
```


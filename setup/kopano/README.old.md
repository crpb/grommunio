# kopano-importer

## Vorbereitungen

Zuerst erstellen wir einen SSH-Key für den Transfer auf grommunio.hostname.domain.tld. Dieser wird dann auf dem Kopano-Host im Benutzer root hinterlegt. Somit können wir ohne Kennworteingabe ein SSHFS einbinden.
##### **`On Grommunio-Host'`**
``` bash
ssh-keygen <Ente><Ente><Ente>
zypper install sshfs
```

##### **`On Kopano-Host'`**
``` bash
echo "PUBKEY" > ~root/.ssh/authorized_keys  
sed -i 's/^.*RootLogin.*$/PermitRootLogin=yes/g' /etc/ssh/sshd_config
systemctl restart ssh

sed -i 's/bind-address.*/bind-addresss = 0.0.0.0/g' /etc/mysqld/mysql.conf.d/mysqld.conf
systemctl restart mysql
mysql -u root -p
CREATE user 'gromox'@'grommunio.domain.tld' identified with mysql_native_password by 'INSERTCOINHERE';
GRANT ALL PRIVILEGES ON zarafa|kopano|databasename.* to 'gromox'@'gromi.domain.tld';
```
> SELECT PRIVILEGES should do aswell?!
##### **`On Grommunio-Host'`**
``` bash
screen -S import
#Export as needed or Change Values in Script.
export SRCHOST=kopano.host.name 
export SQLDB=kopano
export SQLUSR=gromox
export SQLPORT=3306
export LOGDIR=~/
#This is needed!
export SRCPASS=INSERTCOINHERE
./grommunio/setup/kopano/kopano-importer
```
Und warten...

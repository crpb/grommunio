
# First!!!

`DNS Entry for Autodiscover
```
_autodiscover._tcp.MAIL.DOM.    IN      SRV     0       0       443 grommunio.server.name
```


### Active-Directory?

Set 'preferredLanguage'

> Now with Defaults on the Server not that important..

#### **`Powershell`**
``` powershell
$AllUsers=Get-ADUser -Filter *

foreach ($u in $AllUsers){
    Set-ADObject -Identity $u.DistinguishedName -replace @{preferredLanguage="de_DE"}
}
```

### Set Default Locale in Grommunio-Web

#### **`/etc/grommunio-web/config.php`**
``` bash
sed -i 's/en_US.UTF-8/de_DE.UTF-8/g' /etc/grommunio-web/config.php
```

### LDAP only active accounts?
`/etc/gromox/ldap_adaptor.cfg`
```
ldap_user_filter=(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))
```

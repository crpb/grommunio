====================
Grommunio Playground
====================

SHELL-FU
--------

.. code-block:: shell


  #zypper what? i only know about apt!!!
  zypper in zypper-aptitue # !!!!!!!!!!!!!!!
  zypper ref #apt update
  zypper up  #apt dist-upgrade

  #grommunio-admin
  grommunio-admin shrek # ;p
  #create/update all users found in ldap
  grommunio-admin ldap downsync --auto --complete --lang de_DE --yes
  #if we talk about ldap (Active-Directory LANG-Attribute)
  ```powershell
  $AllUsers=Get-ADUser -Filter *
  foreach ($u in $AllUsers)
  {    Set-ADObject -Identity $u.DistinguishedName -replace @{preferredLanguage="de_DE"}}
  ```
  #useful infos
  #get all users
  USERLIST=$(grommunio-admin user list | awk '{print $2}' |grep -v -E '^admin$|^users$')
  #work with that
  for user in $USERLIST; do grommunio-admin user show $user;echo; done
  #query
  #Domains 
  grom_doms=$(grommunio-admin domain list |awk '{print $2}')
  #Users
  grom_users=$(for dom in $grom_doms; do grommunio-admin user query --format json-structured |jq -r '.[]|select(.username|endswith("'${dom}'"))|.username';done)


BACKUP: Work in Progress
----------------------------------
> gromox working
----------------------------------------------------

Setup_ Snapper_ for automatic Backups with grombak_
---------------------------------------------------

.. _Snapper: https://en.opensuse.org/openSUSE:Snapper_Tutorial
  

.. _Setup: https://github.com/crpb/grommunio/blob/main/setup/snapper/setup.sh
  

.. _grombak: https://github.com/crpb/grommunio/blob/main/setup/snapper/grombak
  

This Script doesn't care for _versioning_ because of zfs-snapshots on the NFS-Share

MySQL
-----

Dump
----
.. code-block:: shell
  
  eval `sed 's/ //g' /etc/gromox/mysql_adaptor.cfg`
  mysqldump --user=$mysql_username --password=$mysql_password --databases $mysql_dbname --add-drop-database > grommunio.dump.sql
  
Restore
-------

.. code-block:: shell

  eval `sed 's/ //g' /etc/gromox/mysql_adaptor.cfg`
  mysql --username=$mysql_username --password=$mysql_password $mysql_dbname < grommunio.dump.sql



=========
Appliance
=========
Expanding the Disk 
------------------

Resize the Disk with PowerCLI_

.. _PowerCLI: https://developer.vmware.com/powercli

.. code-block:: powershell

    pwsh
    $myvcenter = Connect-VIServer -Server vcenter-hostname
    Get-VM -Name 'grommunio_appl*'|Get-HardDisk |Set-HardDisk -SizeGB 40
    exit

Actual Resize in the Appliance with help of growpart_

.. _growpart: https://build.opensuse.org/package/show/Cloud:Tools/growpart

.. code-block:: shell

    zypper ref && zypper in growpart -y
    echo 1 > /sys/block/sda/device/rescan
    growpart /dev/sda 3
    btrfs filesystem resize max /


======
Debian
======
NGINX
-----
Additional nginx-modules
------------------------
not maintained in Debian/Ubuntu

take a look at alien8.sh_

.. _alien8.sh: https://github.com/crpb/grommunio/blob/main/debian/alien8.sh

------------------------
`host traffic status`_
------------------------

.. _`host traffic status`: https://github.com/vozlt/nginx-module-vts

-------
brotli_
-------

.. _brotli: https://github.com/google/ngx_brotli

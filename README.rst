=================
Grommunio Helpers
=================

BACKUP
-------------------------
> gromox -> grombak.xfs_
-------------------------

.. _grombak.xfs: https://github.com/crpb/grommunio/blob/main/tools/grombak.xfs
.. _notes: https://community.grommunio.com/d/444-scripting-snippets-notepad/32

This Script doesn't care for _versioning_ because the NFS shareas are ZFS backed
with fitting snapshot tasks in my setups. To make use of LVM Snapshot see my
notes_.



========
Snippets
========

https://community.grommunio.com/d/444-scripting-snippets-notepad/

======
Debian
======
NGINX
-----
Additional nginx-modules
------------------------

take a look at alien8.sh_

.. _alien8.sh: https://github.com/crpb/grommunio/blob/main/debian/alien8.sh

------------------------
`host traffic status`_
------------------------
- not maintained in Debian/Ubuntu

.. _`host traffic status`: https://github.com/vozlt/nginx-module-vts

-------
brotli_
-------
The packages_ for brotli are available since Bookworm and will be installed automatically by grommunio-setup_

.. _brotli: https://github.com/google/ngx_brotli
.. _packages: https://qa.debian.org/cgi-bin/madison.cgi?package=libnginx-mod-http-brotli-filter+libnginx-mod-http-brotli-static&table=debian&a=&c=&s=#
.. _grommunio-setup: https://github.com/eryx12o45/grommunio-setup

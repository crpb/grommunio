#!/usr/bin/python3
#
# SPDX-FileCopyrightText: 2023 Christopher Bock <christopher@bocki.com>
# SPDX-FileCopyrightText: 2023 Walter Hofstaedtler <walter@hofstaedtler.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Reference:
# https://community.grommunio.com/d/1048-midb-what-are-these-databases-for-and-how-to-regenerate-the-midb
#

import sys
import subprocess
import argparse
import json
import pprint

#  # jwilk/python-syntax-errors
#  lambda x, /: 0  # Python >= 3.8 is required
if not sys.version_info >= (3, 9):
    print("Required version Python 3.9")
    sys.exit()

pp = pprint.PrettyPrinter()

__doc__ = "Regenerate the MIDB of Gromox-Mailboxes"

parser = argparse.ArgumentParser(description=__doc__)
group = parser.add_mutually_exclusive_group(required=True)
group.add_argument("--all", action="store_true", default=True, help="All Mailboxes")
group.add_argument(
    "--user", action="store", help="Username of Mailbox, e.g. user@dom.tld"
)
group = parser.add_argument_group("options")
group.add_argument(
    "--backup", action=argparse.BooleanOptionalAction, default=False, help="Backup MIDB"
)
group.add_argument(
    "--recreate",
    action=argparse.BooleanOptionalAction,
    default=True,
    help="Recreate MIDBs",
)
group.add_argument(
    "--dry-run",
    action=argparse.BooleanOptionalAction,
    default=True,
    help="Only show what would happen(default). Use --no-dry-run when ready.",
)
group.add_argument(
    "--verbose", action=argparse.BooleanOptionalAction, default=False, help="Some noise"
)
pargs = parser.parse_args()

if pargs.verbose:
    pp.pprint(pargs)


def backup_midb(users):
    """
    Is actually not really helpful if we run the cleaner afterwards :-) - ~cb
    """
    if pargs.verbose:
        print(f"Backup: {pargs.backup}")
    for user in users:
        args = [
            "sqlite3",
            f"{users[user]}/exmdb/midb.sqlite3",
            f".backup {users[user]}/exmdb/midb.bak.sqlite3",
        ]
        if pargs.verbose:
            print(args)
        if not pargs.dry_run:
            subprocess.call(args, shell=True)


def recreate_midb(users):
    if pargs.verbose:
        print("recreate midbs")
    args = ["systemctl", "stop", "gromox-midb", "gromox-imap", "gromox-pop3"]
    if pargs.verbose:
        print(args)
    if not pargs.dry_run:
        subprocess.call(args)
    for cuser in users:
        if pargs.verbose:
            opts = "-vf"
        else:
            opts = "-f"
        args = ["gromox-mkmidb", f"{opts}", f"{cuser}"]
        if pargs.verbose:
            print(args)
        if not pargs.dry_run:
            subprocess.call(args)
    args = ["systemctl", "restart", "gromox-midb", "gromox-imap", "gromox-pop3"]
    if pargs.verbose:
        print(args)
        print("purge datafiles")
    if not pargs.dry_run:
        subprocess.call(args)
    for cuser in users:
        args = ["gromox-mbop", "-d", f"{users[cuser]}", "purge-datafiles"]
        if pargs.verbose:
            print(args)
        if not pargs.dry_run:
            print(f"Cleaner: {cuser}")
            subprocess.call(args)
        args = ["gromox-mbop", "-d", f"{users[cuser]}", "sync-midb"]
        if pargs.verbose:
            print(args)
        if not pargs.dry_run:
            print(f"Synchronize MIDB: {cuser}")
            subprocess.call(args)


data = ""
gaquery = [
    "grommunio-admin",
    "user",
    "query",
    "username",
    "maildir",
    "--filter",
    "pop3_imap=True",
    "--sort",
    "maildir",
    "--format",
    "json-structured",
]

if pargs.all:
    data = subprocess.check_output(
        gaquery,
        universal_newlines=True,
    )

if pargs.user:
    userfilter = gaquery
    userfilter.extend(["--filter", f"username={pargs.user}"])
    data = subprocess.check_output(
        userfilter,
        universal_newlines=True,
    )

users = {}
for user in json.loads(data):
    users[user["username"]] = user["maildir"]

if pargs.verbose:
    print("Users")
    [(print(value, end="\t"), print(key)) for key, value in users.items()]

if pargs.backup:
    backup_midb(users)
if pargs.recreate:
    recreate_midb(users)

# vim:ts=4 sts=4 sw=4 et

#!/usr/bin/python3
#
# SPDX-FileCopyrightText: 2023 Christopher Bock <christopher@bocki.com>
# SPDX-FileCopyrightText: 2023 Walter Hofstaedtler <walter@hofstaedtler.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Reference:
# https://community.grommunio.com/d/1048-midb-what-are-these-databases-for-and-how-to-regenerate-the-midb
#

import os
import sys
import socket
import time
import subprocess
import argparse
import json
import pprint
import warnings

# we still have a little time left until python3.13!
with warnings.catch_warnings():
    warnings.filterwarnings("ignore",category=DeprecationWarning)
    import telnetlib

#  # jwilk/python-syntax-errors
#  lambda x, /: 0  # Python >= 3.8 is required
if not sys.version_info >= (3, 8):
    print('Required version Python 3.8')
    sys.exit()

pp = pprint.PrettyPrinter()

__doc__ = "Regenerate the MIDB of Gromox-Mailboxes"

parser = argparse.ArgumentParser(description=__doc__)
group = parser.add_mutually_exclusive_group(required=True)
group.add_argument('--all', action='store_true', default=True, help='All Mailboxes')
group.add_argument('--user', action='store', help='Username of Mailbox, e.g. user@dom.tld')
#group.add_argument('--file', action='store', help='Filepath to Userlist')
group = parser.add_argument_group('options')
group.add_argument('--backup', action=argparse.BooleanOptionalAction, default=False, help='Backup MIDB')
group.add_argument('--recreate', action=argparse.BooleanOptionalAction, default=True, help='Recreate MIDBs')
group.add_argument('--dry-run', action=argparse.BooleanOptionalAction, default=True, help='Only show what would happen')
group.add_argument('--verbose', action=argparse.BooleanOptionalAction, default=False, help='Some noise')
pargs = parser.parse_args()

if pargs.verbose: pp.pprint(pargs)

def trigger(users):
    if pargs.verbose: print('Running Trigger')
    telnet_client = telnetlib.Telnet('::1', 5555)
    wcount = 0
    mcount = len(users)
    telnet_client.read_until(b"OK", timeout=10) # wait for OK
    print(f"{mcount} mail directories for MIDB synchronization found.")
    for user in users:
        mbx = users[user]
        time.sleep(1)
        wcount += 1
        print("Mailbox {:>3}: {}".format(wcount, mbx.strip()))
        # Build the synchronization command
        byte_obj = ( "X-RSYM " + mbx.strip() + "\r\n").encode("ascii")
        telnet_client.write(byte_obj)
        telnet_client.read_until(b"TRUE ", timeout=300) # wait max. 5 minutes for TRUE
    print(f"[Closing connection]")
    telnet_client.write(b'exit')

def backup_midb(users):
    '''
    Is actually not really helpful if we run the cleaner afterwards :-) - ~cb
    '''
    if pargs.verbose: print(f'Backup: {pargs.backup}')
    for user in users:
        command = f'sqlite3 {users[user]}/exmdb/midb.sqlite3 ".backup {users[user]}/exmdb/midb.bak.sqlite3"'
        if pargs.verbose: print(command)
        if not pargs.dry_run:
            subprocess.call(command, shell=True)

def recreate_midb(users):
    if pargs.verbose: print(f'recreate midbs: {pargs.dry_run}')
    args = ['systemctl',
            'stop',
            'gromox-midb',
            'gromox-imap',
            'gromox-pop3'
            ]
    if pargs.verbose: print(args)
    if not pargs.dry_run:
        subprocess.call(args)
    for user in users:
        if pargs.verbose: opts='-vf'
        else: opts='-f'
        args = ['gromox-mkmidb',
                f'{opts}',
                f'{user}'
                ]
        if pargs.verbose: print(args)
        if not pargs.dry_run:
            subprocess.call(args)
    args = ['systemctl',
            'restart',
            'gromox-midb',
            'gromox-imap',
            'gromox-pop3'
            ]
    if pargs.verbose: print(args)
    if not pargs.dry_run:
        subprocess.call(args)
    for user in users:
        args = ['/usr/libexec/gromox/cleaner',
                '-d',
                f'{users[user]}'
                ]
        if pargs.verbose: print(args)
        if not pargs.dry_run:
            print(f'Cleaner: {user}')
            subprocess.call(args)

if pargs.all:
    data = subprocess.check_output(
            ['grommunio-admin',
                'user',
                'query',
                'username',
                'maildir',
                '--filter',
                'pop3_imap=True',
                '--sort',
                'maildir',
                '--format',
                'json-structured'
                ],
            universal_newlines=True)

if pargs.user:
    data = subprocess.check_output(
            ['grommunio-admin',
                'user',
                'query',
                'username',
                'maildir',
                '--filter',
                'pop3_imap=True',
                '--sort',
                'maildir',
                '--format',
                'json-structured',
                '--filter',
                f'username={pargs.user}'
                ],
            universal_newlines=True)

users = {}
for user in json.loads(data):
    users[user['username']] = user['maildir']

if pargs.verbose: 
    print('Users')
    [(print(value, end='\t'), print(key)) for key, value in users.items()]

if pargs.backup: backup_midb(users)
if pargs.recreate: recreate_midb(users)
if not pargs.dry_run: trigger(users)

# vim:ts=4 sts=4 sw=4 et

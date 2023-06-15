#!/usr/bin/env python3
import argparse
from datetime import datetime
from imap_tools import MailBox, AND, MailMessageFlags


__author__ = "Christopher Bock"
__copyright__ = "Christopher Bock"
__license__ = "MIT License (Expat)"
__doc__ = "Capture all those Flags!!!!"

parser = argparse.ArgumentParser(description=__doc__)
group = parser.add_argument_group("filters")
group.add_argument(
    "--years", metavar="N", type=int, default=1, help="years in the past"
)
group.add_argument("--flagged", action=argparse.BooleanOptionalAction, default=True)
group = parser.add_argument_group("options")
group.add_argument("--mark", action=argparse.BooleanOptionalAction, default=False)
group.add_argument("--limit", metavar="N", type=int, default=50)
group.add_argument("--unflag", action="store_true")
group = parser.add_argument_group("imap")
group.add_argument("server")
group.add_argument("username")
group.add_argument("password")
args = parser.parse_args()

dt = datetime.now()
dt = dt.replace(year=dt.year - args.years)

"""
Iterate over all Folders
Look for [Not]Flagged Messages
and whatever...
"""
crit = AND(flagged=args.flagged, date_lt=dt.date())
if args.unflag:
    print(f"Mailbox: {args.username}")
    with MailBox(args.server).login(args.username, args.password) as mailbox:
        for f in mailbox.folder.list():
            print(f"\t{f.name}")
            mailbox.folder.set(f.name)
            FLAGS = MailMessageFlags.SEEN
            print("\t\tSET SEEN")
            mailbox.flag(mailbox.uids(crit), FLAGS, True)
            FLAGS = MailMessageFlags.FLAGGED
            print("\t\tUNFLAGGING")
            mailbox.flag(mailbox.uids(crit), FLAGS, False)
# If we don't want to take action we will see what we would have matched
else:
    with MailBox(args.server).login(args.username, args.password) as mailbox:
        for f in mailbox.folder.list():
            mailbox.folder.set(f.name)
            for msg in mailbox.fetch(
                mark_seen=args.mark, criteria=crit, limit=args.limit
            ):
                print(f.name, msg.date, msg.subject[0:30], len(msg.text or msg.html))

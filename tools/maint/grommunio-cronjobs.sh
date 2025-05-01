#!/bin/bash

# Load function library
. /usr/local/bin/grommunio-functions.sh


### Retrieve data ###

## List all domains
# Usage: grom_domains

# Example 1: List all domains
#grom_domains


## List all users for one or all domains
# Usage: grom_users [domain]

# Example 1: List users of all domains
#grom_users
# Example 2: List users of domain abc.com
#grom_users abc.com



### Cleanup messages ###

## Delete messages older than a defined retention period (incl. cleaning up the mail directory)
# Usage: grom_purge_messages domain folder retention_days
# domain          can be a domain name such as 'abc.com' or 'all' for all domains
# folder          one of the following types: INBOX, OUTBOX, DRAFT, SENT, DELETED, JUNK or all
# retention_days  integer to define the retention period, e.g. 30 days => all messages older than 30 days will be deleted

# Example 1: Delete all junk messages older than 30 days for all domains
#grom_purge_messages all JUNK 30
# Example 2: Delete all messages older than 730 days (2 years) for all domains
#grom_purge_messages all all 730
# Example 3: Delete all messages older than 365 days (1 year) for domain abc.com
#grom_purge_messages abc.com all 365


## Query how many messages would be deleted
# Usage: grom_query_purge_count domain folder retention_days
# domain          can be a domain name such as 'abc.com' or 'all' for all domains
# folder          one of the following types: INBOX, OUTBOX, DRAFT, SENT, DELETED, JUNK or all
# retention_days  integer to define the retention period, e.g. 30 days => all messages older than 30 days will be deleted

# Example 1: Get the count of junk messages older than 30 days for all domains
#grom_query_purge_count all JUNK 30
# Example 2: Get the count of all messages older than 730 days (2 years) for all domains
#grom_query_purge_count all all 730
# Example 3: Get the count of all messages older than 365 days (1 year) for domain abc.com
#grom_query_purge_count abc.com all 365


## Cleanup user mail directories from old, deleted messages
# Usage: grom_cleanup domain
# domain  can be a domain name such as 'abc.com' or 'all' for all domains

# Example 1: Clean up user mail directories of all domains
#grom_cleanup all
# Example 2: Clean up user mail directories of domain abc.com
#grom_cleanup abc.com



### Backup data ### 

## Backup user objects like calender, contacts, etc. to a tar.bz2 file per domain
# NOTE: mail messages are not backed up by intention as there are enough other means to backup mails
# Usage: grom_backup_messages domain target_folder message_type
# domain         can be a domain name such as 'abc.com' or 'all' for all domains
# target_folder  defines the folder where the resulting files are stored
# message_type   one of the following types: CALENDAR, CONTACTS, JOURNAL, TASKS, NOTES or all

# Example 1: Backup all objects for all domains
#grom_backup_messages all /root/backup all
# Example 2: Backup all calendar and contact objects for all domains
#grom_backup_messages all /root/backup CALENDAR
#grom_backup_messages all /root/backup CONTACTS
# Example 3: Backup all objects for domain abc.com
#grom_backup_messages abc.com /root/backup all



### Learn ham/spam ###

## Rspamd spam/ham learning for grommunio
## NOTE: the officially published scripts from grommunio work differently and do not consider spam-flag
# The spam function passed all messages in the junk folder with spam-flag=0 to rspamd,
# while the ham function passes all messages in the indox folder with spam-flag=1 to rspamd
# Usage: grom_rspamd_learn type history_days
# type          one of the following types: ham, spam or all
# history_days  integer to define the history period, e.g. 7 days => all messages modified in the past 7 days will be considered

# Example 1: Learn both ham and spam and consider the past 30 days
#grom_rspamd_learn all 30
# Example 2: Learn only ham and consider the past 7 days
#grom_rspamd_learn ham 7 (or grom_learn_ham 7)
# Example 3: Learn only spam and consider the past 7 days
#grom_rspamd_learn spam 7 (or grom_learn_spam 7)


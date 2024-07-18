#! /bin/bash
#
# (c) 2023 by Walter Hofstaedtler and cb
#
# Authors: Walter Hofstaedtler <walter@hofstaedtler.com>
#          Christopher Bock <christopher@bocki.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Stored in WHIE GIT: git@icc-srv:/whie/grommunio/tools.git
#
# V.: 1.0 12.08.2023 initial release
# V.: 1.1 14.08.2023 some improvements like getopts and $GADMINRES, thanks to cb
#
# Instructions:
#    1. copy the script to the grommunio server like /scripts/g_user_count.sh
#    2. convert the script to Linux LF: dos2unix /scripts/g_user_count.sh
#    3. make the script executable ...: chmod +x /scripts/g_user_count.sh
#    4. launch the script ............: /scripts/g_user_count.sh
#    Use parameter:
#       -u  list active users / mailboxes
#       -s  list suspended users / mailboxes
#       -m  list shared mailboxes
#       -g  list groups / distribution lists
#       -a  show all 4 lists
#       -h  show help message
#
# Unwanted messages: "[INFO] (mysql) Detected database schema version n122"
# If you see messages like: "[INFO] (mysql) Detected database schema version n122"
# Edit /etc/grommunio-admin-api/conf.d/logging.yaml, change INFO to WARNING and restart admin-api
# systemctl restart grommunio-admin-api
#
#
RED="\033[0;31m"; YEL="\033[0;33m"; GRN="\033[0;32m"; CYA="\033[0;36m"; NORM="\033[0m"
DO_HELP=0; DO_USERS=0; DO_SUSPEND=0; DO_SHARED=0; DO_GROUPS=0; DO_CONTACTS=0
#
echo
echo -e "${CYA}Count grommunio Users / Mailboxes ${NORM}"
echo -e "${CYA}V.: 1.1, (c) 2023 by Walter@Hofstaedtler.com and cb ${NORM}"
echo
#
OPTIND=1
while getopts ":ausmgh" opt; do
    case $opt in
        u)  DO_USERS=1
            ;;
        s)  DO_SUSPEND=1
            ;;
        m)  DO_SHARED=1
            ;;
        g)  DO_GROUPS=1
            ;;
        c)  DO_CONTACTS=1
            ;;
        a)  DO_USERS=1
            DO_SUSPEND=1
            DO_SHARED=1
            DO_GROUPS=1
            DO_CONTACTS=1
            ;;
        h)  DO_HELP=1
            ;;
        *)  DO_HELP=1
            echo -e "${YEL}ERROR: invalid parameter!${NORM}\n"
            ;;
    esac
done
shift $((OPTIND - 1))
#
if [ "$DO_HELP" -eq 1 ]; then
    echo -e "${CYA}Help for ${BASH_SOURCE[0]}:${NORM}"
    echo -e " -u  list active users / mailboxes"
    echo -e " -s  list suspended users / mailboxes"
    echo -e " -m  list shared mailboxes"
    echo -e " -g  list groups / distribution lists"
    echo -e " -c  list contacts"
    echo -e " -a  show all 5 lists"
    echo -e " -h  show this help message"
    echo
    exit 1
fi
#
echo -e "Counting items please wait ..."
echo
GADMINRES="$(grommunio-admin user query username maildir status)"
USERS="$(grep '/var/lib/' <<< "$GADMINRES" | grep -c 0/active)"
SUSPENDED="$(grep '/var/lib/' <<< "$GADMINRES" | grep -c 1/suspended)"
CONTACTS="$(grep -v '/var/lib/' <<< "$GADMINRES" | grep -c 5/contact)"
SHARED_MB="$(grep '/var/lib/' <<< "$GADMINRES" | grep -c 4/shared)"
DIST_LIST="$(grep -v '/var/lib/' <<< "$GADMINRES" | grep -c "@")"
TOTAL_ADMIN="$(grep '/var/lib/' <<< "$GADMINRES" | grep -c "@")"
#
TOTAL_USERS=$((USERS + SUSPENDED))
TOTAL_COUNT=$((USERS + SHARED_MB + SUSPENDED))
#
if [ "$DO_USERS" -eq 1 ] && [ "$USERS" -gt 0 ]; then
    echo -e "${CYA}List active users:${NORM}"
    grep '/var/lib/.*0/active' <<< "$GADMINRES" | sort | awk '{ print "  " $1 }'
    MZ=""; [ "$USERS" -ne 1 ] && MZ="s"
    echo -e "${YEL}${USERS} active user${MZ}${NORM}\n"
fi
#
if [ "$DO_SUSPEND" -eq 1 ] && [ "$SUSPENDED" -gt 0 ]; then
    echo -e "${CYA}List suspended users:${NORM}"
    grep '/var/lib/.*1/suspended' <<< "$GADMINRES" | sort | awk '{ print "  " $1 }'
    MZ=""; [ "$SUSPENDED" -ne 1 ] && MZ="s"
    echo -e "${YEL}${SUSPENDED} suspended user${MZ}${NORM}\n"
fi
#
if [ "$DO_SHARED" -eq 1 ] && [ "$SHARED_MB" -gt 0 ]; then
    echo -e "${CYA}List shared mailboxes:${NORM}"
    grep '/var/lib/.*4/shared' <<< "$GADMINRES" | sort | awk '{ print "  " $1 }'
    MZ=""; [ "$SHARED_MB" -ne 1 ] && MZ="es"
    echo -e "${YEL}${SHARED_MB} shared mailbox${MZ}${NORM}\n"
fi
#
if [ "$DO_GROUPS" -eq 1 ] && [ "$DIST_LIST" -gt 0 ]; then
    echo -e "${CYA}List groups / distribution lists:${NORM}"
    grep -v '/var/lib/' <<< "$GADMINRES" | grep "@" | sort | awk '{ print "  " $1}'
    MZ=""; [ "$DIST_LIST" -ne 1 ] && MZ="s"
    echo -e "${YEL}${DIST_LIST} groups / distribution list${MZ}${NORM}\n"
fi
#
printf -v T_U "% 4d" "$TOTAL_USERS"
printf -v D_L "% 4d" "$DIST_LIST"
printf -v S_M "% 4d" "$SHARED_MB"
printf -v T_C "% 4d" "$TOTAL_COUNT"
printf -v O_C "% 4d" "$CONTACTS"
#
# Print summary
echo -e "${GRN}${T_U}${NORM} users / mailboxes to be ${GRN}licensed${NORM}, includes ${SUSPENDED} suspended users, rooms and equipment,"
echo -e "${RED}${S_M}${NORM} shared mailboxes (free),"
echo -e "${YEL}${D_L}${NORM} groups / distribution lists (free),"
echo -e "${CYA}${T_C}${NORM} mailboxes total."
echo -e "${GRN}${O_C}${NORM} contacts."
#
if [ "$TOTAL_ADMIN" -ne "$TOTAL_COUNT" ]; then
    echo -e "${RED}ERROR:${NORM} TOTAL count do ${RED}*NOT*${NORM} match grommunio-admin user count!${NORM}, grommunio-admin: ${RED}${TOTAL_ADMIN}${NORM}, my count: ${YEL}${TOTAL_COUNT}${NORM}!"
    echo -e "${RED}This summary is probably incorrect.${NORM}"
    echo -e "Consider to report this issue to: Walter@Hofstaedtler.com."
    exit 70 # EX_SOFTWARE /* internal software error */
fi
echo
# --- eof ---
#
# vim: syntax=bash ts=4 sw=4 sts=4 sr noet :

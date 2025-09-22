#! /bin/bash
#
# (c) 2023 by Walter Hofstaedtler and cb
#
# Authors: Walter Hofstaedtler <walter@hofstaedtler.com>
#          crpb <christopher@bocki.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Stored in WHIE GIT: git@icc-file:/whie/grommunio/tools.git
#
# V.: 1.0 12.08.2023 initial release
# V.: 1.1 14.08.2023 some improvements like getopts and $GADMINRES, thanks to crpb
# V.: 1.2 16.07.2025 suspended mailboxes now counted as free, grommunio repaired the admin-api
# V.: 1.3 22.09.2025 Read Grommunio license information, implemented crpb
#
# Instructions:
#    1. copy the script to the grommunio server like /scripts/manual/g_user_count.sh
#    2. convert the script to Linux LF: dos2unix /scripts/manual/g_user_count.sh
#    3. make the script executable ...: chmod +x /scripts/manual/g_user_count.sh
#    4. launch the script ............: /scripts/manual/g_user_count.sh
#    Use parameter:
#       -u  list active users / mailboxes
#       -s  list suspended users / mailboxes
#       -m  list shared mailboxes
#       -g  list groups / distribution lists
#       -c  list contacts
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
DO_HELP=false; DO_USERS=false; DO_SUSPEND=false; DO_SHARED=false; DO_GROUPS=false; DO_CONTACTS=false
#
echo
echo -e "${CYA}Count grommunio Users / Mailboxes ${NORM}"
echo -e "${CYA}V.: 1.3, (c) 2023-2025 by Walter@Hofstaedtler.com and crpb ${NORM}"
echo
#
#
OPTIND=1
while getopts ":acusmgh" opt; do
    case $opt in
        u)  DO_USERS=true
            ;;
        s)  DO_SUSPEND=true
            ;;
        m)  DO_SHARED=true
            ;;
        g)  DO_GROUPS=true
            ;;
        c)  DO_CONTACTS=true
            ;;
        a)  DO_USERS=true
            DO_SUSPEND=true
            DO_SHARED=true
            DO_GROUPS=true
            DO_CONTACTS=true
            ;;
        h)  DO_HELP=true
            ;;
        *)  DO_HELP=true
            echo -e "${YEL}ERROR: invalid parameter!${NORM}\n"
            ;;
    esac
done
shift $((OPTIND - 1))
#
if $DO_HELP; then
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
#TOTAL_USERS=$((USERS + SUSPENDED))
TOTAL_USERS=$USERS
TOTAL_FREE=$((SHARED_MB + SUSPENDED))
TOTAL_COUNT=$((USERS + SHARED_MB + SUSPENDED))
#
if $DO_USERS && [ "$USERS" -gt 0 ]; then
    echo -e "${CYA}List active users:${NORM}"
    grep '/var/lib/.*0/active' <<< "$GADMINRES" | sort | awk '{ print "  " $1 }'
    MZ=""; [ "$USERS" -ne 1 ] && MZ="s"
    echo -e "${YEL}${USERS} active user${MZ}${NORM}\n"
fi
#
if $DO_SUSPEND && [ "$SUSPENDED" -gt 0 ]; then
    echo -e "${CYA}List suspended users:${NORM}"
    grep '/var/lib/.*1/suspended' <<< "$GADMINRES" | sort | awk '{ print "  " $1 }'
    MZ=""; [ "$SUSPENDED" -ne 1 ] && MZ="s"
    echo -e "${YEL}${SUSPENDED} suspended user${MZ}${NORM}\n"
fi
#
if $DO_SHARED && [ "$SHARED_MB" -gt 0 ]; then
    echo -e "${CYA}List shared mailboxes:${NORM}"
    grep '/var/lib/.*4/shared' <<< "$GADMINRES" | sort | awk '{ print "  " $1 }'
    MZ=""; [ "$SHARED_MB" -ne 1 ] && MZ="es"
    echo -e "${YEL}${SHARED_MB} shared mailbox${MZ}${NORM}\n"
fi
#
if $DO_GROUPS && [ "$DIST_LIST" -gt 0 ]; then
    echo -e "${CYA}List groups / distribution lists:${NORM}"
    grep -v '/var/lib/' <<< "$GADMINRES" | grep "@" | sort | awk '{ print "  " $1}'
    MZ=""; [ "$DIST_LIST" -ne 1 ] && MZ="s"
    echo -e "${YEL}${DIST_LIST} groups / distribution list${MZ}${NORM}\n"
fi
#
if $DO_CONTACTS && [ "$CONTACTS" -gt 0 ]; then
    echo -e "${CYA}List contacts:${NORM}"
    CONTACT=$(awk '/5\/contact/{print $1}' <<< "$GADMINRES")
    grommunio-admin shell -n <<< "$(for contact in $CONTACT; do
        printf "user show %s\n" "$contact"; done)"|&
        awk -F ': ' '
            {if ($1~/username/) {printf "  %s", $2}
            else if ($1~/smtpaddress/) {printf "\t%s\n", $2}}'
    MZ=""; [ "$CONTACTS" -ne 1 ] && MZ="s"
    echo -e "${YEL}${CONTACTS} contact${MZ}${NORM}\n"
fi
#
printf -v T_U "% 4d" "$TOTAL_USERS"
printf -v T_F "% 4d" "$TOTAL_FREE"
printf -v D_L "% 4d" "$DIST_LIST"
printf -v S_M "% 4d" "$SHARED_MB"
printf -v T_C "% 4d" "$TOTAL_COUNT"
printf -v S_U "% 4d" "$SUSPENDED"
printf -v O_C "% 4d" "$CONTACTS"
#
# Read Grommunio license information
LICENSE=/etc/grommunio-admin-common/license/license.crt
if [ -f "$LICENSE" ]; then
    X509DATA=$(openssl x509 -noout -in "$LICENSE" -text |sed -e 's/^[ \t]*//')
    if [ -n "$X509DATA" ]; then
        LICENSE_TYPE=$(sed -n '/1.3.6.1.4.1.56504.1.2/{n;p}' <<< "$X509DATA")
        LICENSE_COUNT=$(sed -n '/1.3.6.1.4.1.56504.1.1/{n;p}' <<< "$X509DATA")
        printf -v L_C "% 4d" "$LICENSE_COUNT"
    fi
fi
# Print summary
echo -e "${GRN}${T_U}${NORM} users / mailboxes to be ${YEL}licensed${NORM},"
if [ -n "$LICENSE_COUNT" ]; then
    echo -e "${GRN}${L_C}${NORM} users with ${YEL}${LICENSE_TYPE} ${GRN}licensed!${NORM}"
fi
echo -e "${YEL}${S_M}${NORM}   shared mailboxes (free),"
echo -e "${YEL}${S_U}${NORM}   suspended mailboxes (free),"
echo -e "${RED}${T_F}${NORM} number of free mailboxes,"
echo -e "${CYA}${T_C}${NORM} mailboxes total (free and paid)."
echo -e "${YEL}${D_L}${NORM}   groups / distribution lists (free),"
echo -e "${GRN}${O_C}${NORM}   contacts (free)."
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

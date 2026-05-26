#!/bin/bash
#
# (c) 2022-2026 by Walter@Hofstaedtler.com
# Stored in WHIE GIT: git@icc-file:/whie/grommunio/tools.git
#
# This is free software, use it at your own risk.
#
#
# This script cleans up mailboxes and public folders for domains.
# We use gromox-mbop to purge softdelete after a settable time, and to purge
# outdated message files and purge sync_issues, conflicts and failures folders.
# It also cleans the Outbox folder to remove any leftover items after core dumps.
# The trash bin can also be purged after a settable time.
#
#
# Juni 2023, cleaner has been replaced by `gromox-mbop -u MAILBOX purge-datafiles`
# Juni 2025, Added COUNTers for output, colorized output
# Juni 2025, Script is more configurable and better structured
# Juni 2025, Logging is now in System-D journal, use "journalctl -f -t g_cleaner" to read the journal
# Juni 2025, Silence mode for crontab, create crontab, help message, debug and more
# Juni 2025, Purge the 4 "SYNC_ISSUES" folders
# Juni 2025, Create systemd timer and service files
# Juli 2025, Add cleanup trashbin: $GROMOX_MBOP -u $mailbox emptyfld -R --delempty --soft -t "${TRASHBIN_RETENTION}" DELETED
#            https://github.com/crpb/grommunio/blob/main/tools/grombak.xfs#L106-L108
# Juli 2025, Modification from CRPB: 'SYNC_ISSUES CONFLICTS LOCAL_FAILUES SERVER_FAILURES'
# Juli 2025, Added message about 'systemctl daemon-reload'
# Juli 2025, Check if required files (gromox-mbop and grommunio-admin) are exists
# Juli 2025, Restructured the code flow
# Juli 2025, Vacuuming is a very CPU- and time-consuming process, there is no need to do
#            it every day. A list of weekdays has been added for both vacuum operations,
#            indicating when a vacuum operation should be performed.
#            (0 = Sunday, 1 = Monday, ..., 6 = Saturday), or select X to turn off vacuum.
# Juli 2025, Removed the [Install] section from service and do *NOT* enable the service
#            to prevent launching the script at boot
# Dez. 2025, The 'OUTBOX'/'Postausgang' folder has been added to be cleaned. Due to the
#            core dumps, defective items were left in the 'OUTBOX' folder.
# Jan. 2026, Added option to ignore mailboxes starting with a specific text like "archive_".
#            Added some statistics and runtime.
#            Added a g_cleaner.local override file for configuration. This is similar to the fail2ban .local file.
#            Added a warning message if purging needs longer than nn seconds.
#            The formatting has been improved for the screen and logger.
#            Regex was used to allow multiple patterns for pattern matching with ignore mailboxes.
#            Make the "OnCalendar" parameter configurable.
# Feb. 2026, Replaced color code from Blue with bright Blue.
# Mar. 2026, Corrected a typo: LOCAL_FAILUES -> LOCAL_FAILURES.
# Apr. 2026, Minor corrections, mostly style.
# May. 2026, Added Recalculates the store size after purge-datafiles.
#            Replaced color code from Red with bright Red.
#
#
#
# Installation:
# 1. Place this script in the /scripts/cron/ directory as g_cleaner.sh
# 2. Use the dos2unix command to convert the script to Linux line feeds:
#    dos2unix /scripts/cron/g_cleaner.sh
# 3. Make the script executable:
#    chmod +x /scripts/cron/g_cleaner.sh
# 4. Create the overwrite file g_cleaner.local with:
#    /scripts/cron/g_cleaner.sh -o
# 5. Only modify the options in '/scripts/cron/g_cleaner.local' that you need to adapt.
# 6. Test the script manually.
# 7. To launch the script periodically, create the systemd timer with:
#    /scripts/cron/g_cleaner.sh -t
#
#
# Systemd Journal:
# To view the logs in systemd, use the command: 'journalctl -t g_cleaner.sh'
# or 'journalctl -ft g_cleaner.sh' for continuous logging.
#
#
# Variables to be set by the user of this script
#
# Configure the parameters in the g_gleaner.local file in the same directory
# where g_cleaner.sh is located.
# To create the g_gleaner.local template file, run 'g_cleaner.sh -o' and edit the
# parameters you want to adjust in the g_gleaner.local file.
#
# How long a Soft deleted message is retained:
SOFTDELETE_RETENTION=70d20h
#
# How long elements in trash bin are retained:
TRASHBIN_RETENTION=300d10h
#
# Cleanups to do:
# Clean the SYNC_ISSUES/*, 4 folders - gromox-mbop(8) "Folder specification"
MAIL_SYNC=true
#
# Clean the 'OUTBOX'/'Postausgang' folder (>= 10 min. old) - gromox-mbop(8) "Folder specification"
MAIL_OUTBOX=true
#
# Purge softdelete regarding $SOFTDELETE_RETENTION
MAIL_SOFT=true
#
# Purge trashbin regarding $TRASHBIN_RETENTION
MAIL_TRASH=false
#
# Purge orphaned data files from mailbox
MAIL_DATA=true
#
# Vacuum the user database at week day? Select X to switch off.
# Where 0 = Sunday, 1 = Monday, ..., 6 = Saturday.
# If you need to use multiple days, separate them with '|'.
# MAIL_VACU_DOW="1|3|5" (e.g., 1|3|5 for Mon, Wed, Fri)
MAIL_VACU_DOW="6"
#
# Clean the domain directories / Public store
DOM_DIR=true
#
# Vacuum the domain databases at week day? Select X to switch off,
# where 0 = Sunday, 1 = Monday, ..., 6 = Saturday.
# If you need to use multiple days, separate them with '|'.
# DOM_VACU_DOW="1|3|5" (e.g., 1|3|5 for Mon, Wed, Fri)
DOM_VACU_DOW="X"
#
# Ignore mailboxes where the email address starts with specific text, such as 'archive_'.
# To disable this feature, set the variable to '@@' — a valid email address can never start with '@@'.
# Only use lowercase, as the email address is converted to lowercase before comparison.
# If you need to use multiple patterns, separate them with '|', e.g.: "archive_|backup_|test".
#IGNORE_MBX="archive_|test_"
IGNORE_MBX="@@"
#
# Print a warning if the purge process for a mailbox takes longer than nn
# seconds. To disable this feature, set the value to 99999.
WARNING_SEC=120
#
# Set the periodic start time of the script for the systemd timer.
ON_CALENDAR="*-*-* 04:04:00"
#
# Send debug emails, this is a comma-separated list of email addresses.
# To disable this feature, leave the field empty.
# DEBUG_MAIL="name1@domain.tld,name2@domain.tld"
DEBUG_MAIL=""
#
#
#
# From here on, no code or variables need changing by the user of this script
#
# Read the g_cleaner.local file to override the default parameters.
sLOCAL_FILE=$(realpath "$0")
sLOCAL_FILE=${sLOCAL_FILE%.*}.local
#echo "Local Path: $sLOCAL_FILE"
# shellcheck source=/dev/null
[ -f "$sLOCAL_FILE" ] && . "$sLOCAL_FILE"


# Variables for saving the parameters
bSILENT=false
bDEBUG=false
bLOGSD=false
bHELP=false
bHELP_ERROR=false
bCREATE_TIMER=false
bUNINSTALL_TIMER=false
bCREATE_LOCAL=false
#
# Read the script name
sSCRIPT_NAME=${0##*/}               # remove path
sSCRIPT_NAME=${sSCRIPT_NAME%%.*}    # remove extension
#
# Color
CYA="\033[0;36m"; YEL="\033[0;33m"; BLU="\033[0;94m"; RED="\033[0;91m"; NORM="\033[0m"
#
#
# === Functions of this script
#
Help() {
    # Display Help, $1 is the exit error state
    echo -e "${CYA}Cleanup script for grommunio, purge softdeleted elements and remove outdated files.${NORM}"
    echo
    echo -e "${YEL}Syntax: ${sSCRIPT_NAME}.sh [-h|t|U|s|L|d|x]${NORM}"
    echo -e "${CYA}Options:${NORM}"
    echo -e "${CYA}-h     Print this help.${NORM}"
    echo -e "${CYA}-t     Create the systemd timer files.${NORM}"
    echo -e "${CYA}-U     Uninstall / remove the systemd timer files.${NORM}"
    echo -e "${CYA}-o     Create the g_cleaner.local override file.${NORM}"
    echo -e "${CYA}-s     Silence mode for crontab usage.${NORM}"
    echo -e "${CYA}-L     Do NOT write to systemd log, if run from a systemd service.${NORM}"
    echo -e "${BLU}-d     Debug mode, show more informations.${NORM}"
    echo -e "${BLU}-x     Enables bash debug output.${NORM}"
    echo
    echo -e "${CYA}Note: Edit this script to enable the cleaning options you require.${NORM}"
    echo
    exit "$1"
}
#
#
# Removes ANSI color escape codes and write to the systemd log
logg() {
    # When running from an systemd service, all output is written to the systemd journal
    # Enable logging only for manual usage or cron tab usage
    $bLOGSD || echo -e "$1" | sed -e 's/\x1b\[[0-9;]*m//g' | systemd-cat -t "$sSCRIPT_NAME" -p info;
}
#
#
# Create the systemd timer files in /usr/lib/systemd/system/
CreateTimer() {
    sCRON_FILE="/etc/cron.d/$sSCRIPT_NAME"
    #
    sTIMER_FILE="/usr/lib/systemd/system/$sSCRIPT_NAME.timer"
    sSERVICE_FILE="/usr/lib/systemd/system/$sSCRIPT_NAME.service"
    echo -e "${CYA}\nTry to create the systemd timer files.${NORM}\n"
    if [ -f "$sTIMER_FILE" ] || [ -f "$sSERVICE_FILE" ]; then
        echo -e "${RED}Error the file ${NORM}$sTIMER_FILE ${RED}and/or${NORM}"
        echo -e "$sSERVICE_FILE ${RED}already exists.${NORM}"
        echo -e "${YEL}We will not overwrite the existing systemd timer files.${NORM}"
        echo -e "${YEL}Please remove the files:${NORM}"
        echo -e "$sTIMER_FILE${YEL} and${NORM}"
        echo -e "$sSERVICE_FILE ${YEL}and run${NORM}"
        echo -e "${YEL}the script again to create the systemd timer files.${NORM}\n"
        exit 1
    fi
   # Now create the systemd timer files
    echo -e "${CYA}Systemd timer files not found, create the systemd timer files.${NORM}"
    echo -e "${CYA}1. Create the file: $sTIMER_FILE${NORM}"
    {
        echo "[Unit]"
        echo "Description=Timer to run the clean up script"
        echo "# (c) 2022-2026 by Walter@Hofstaedtler.com"
        echo ""
        echo "[Timer]"
        echo "# DayOfWeek Year-Month-Day Hour:Minute:Second"
        # Use this parameter to set the periodic start time of the script.
        #echo "OnCalendar=*-*-* 04:04:00"
        echo "OnCalendar=${ON_CALENDAR}"
        echo "RandomizedDelaySec=30"
        echo "Persistent=false"
        echo ""
        echo "[Install]"
        echo "WantedBy=timers.target"
    } > "$sTIMER_FILE"

    echo -e "${CYA}2. Create the file: $sSERVICE_FILE${NORM}"
    {
        echo "[Unit]"
        echo "Description=To run the clean up script"
        echo "# (c) 2022-2026 by Walter@Hofstaedtler.com"
        echo ""
        echo "[Service]"
        echo "ProtectSystem=full"
        echo "ProtectHome=true"
        echo "PrivateDevices=true"
        echo "ProtectHostname=true"
        echo "ProtectClock=true"
        echo "ProtectKernelTunables=true"
        echo "ProtectKernelModules=true"
        echo "ProtectKernelLogs=true"
        echo "ProtectControlGroups=true"
        echo "RestrictRealtime=true"
        echo "Type=oneshot"
        echo "User=root"
        echo "ExecStart=$(realpath "$0") -L"
    } > "$sSERVICE_FILE"
    #
    echo -e "${CYA}3. Do a daemon-reload${NORM}"
    systemctl daemon-reload
    #
    echo -e "${CYA}4. Enable and start the timer${NORM}"
    systemctl enable --now "$sSCRIPT_NAME".timer
    #
    echo -e "${CYA}5. Show the new timer: $sSCRIPT_NAME.timer${NORM}"
    systemctl list-timers "$sSCRIPT_NAME".timer
    #
    if [ -f "$sCRON_FILE" ]; then
        echo -e "${YEL}6. $sCRON_FILE found, move it to /root/${NORM}"
        mv "$sCRON_FILE" /root/
    fi
    #
    echo -e "${CYA}If you need to change the execution time in ${YEL}$sTIMER_FILE${NORM},"
    echo -e "${CYA}remember to reload the daemons with: ${YEL}systemctl daemon-reload${NORM}."
    echo
    echo -e "${CYA}To show the installed systemd timers use: ${YEL}systemctl list-timers --all${NORM}."
    echo
    # done
    exit 0
}
#
#
# Uninstall / remove the systemd timer files in /usr/lib/systemd/system/ and stop the timer and service
UninstallTimer() {
    #
    sTIMER_FILE="/usr/lib/systemd/system/$sSCRIPT_NAME.timer"
    sSERVICE_FILE="/usr/lib/systemd/system/$sSCRIPT_NAME.service"
    #
    sCRON_FILE="/root/$sSCRIPT_NAME"
    if [ -f "$sCRON_FILE" ]; then
        echo -e "${YEL}4. saved $sCRON_FILE found, move it to /etc/cron.d/${NORM}"
        mv "$sCRON_FILE" /etc/cron.d/
    fi
    #
    echo -e "${CYA}3. Disable and stop the timer${NORM}"
    systemctl disable --now "$sSCRIPT_NAME".timer
    #
    echo -e "${CYA}2. remove the time and service file${NORM}"
    if [ -f "$sTIMER_FILE" ]; then
        echo "   Remove: $sTIMER_FILE"
        rm "$sTIMER_FILE"
      else
        echo "   Warning: $sTIMER_FILE not found!"
    fi
    if [ -f "$sSERVICE_FILE" ]; then
        echo "   Remove: $sSERVICE_FILE"
        rm "$sSERVICE_FILE"
      else
        echo "   Warning: $sSERVICE_FILE not found!"
    fi
    #
    echo -e "${CYA}1. Do a daemon-reload${NORM}"
    systemctl daemon-reload
    #
    echo -e "${CYA}Done, run ${YEL}$(realpath "$0") -t${CYA} to test systemd timer creation.${NORM}"
    echo
    echo -e "${CYA}To show the installed systemd timers use: ${YEL}systemctl list-timers --all${NORM}."
    echo
    # Done
    exit 0
}
#
#
# Create the g_cleaner.local file in same place as g_cleaner.sh exists.
CreateLocal() {
    echo -e "${CYA}\nTry to create the g_cleaner.local override file.${NORM}\n"
    if [ -f "$sLOCAL_FILE" ]; then
        echo -e "${RED}Error the file ${NORM}$sLOCAL_FILE ${RED}already exists.${NORM}"
        echo -e "${YEL}We will not overwrite the existing override file.${NORM}"
        echo -e "${YEL}Please remove the file:${NORM} $sLOCAL_FILE ${YEL}and run${NORM}"
        echo -e "${YEL}the script again to create the g_cleaner.local file.${NORM}\n"
        exit 1
    fi
   # Now create the g_cleaner.local file.
    echo -e "${CYA}1. Create the file: $sLOCAL_FILE${NORM}"
    {
        echo "# Please read the instructions in $(realpath "$0") on how to set the variables."
        echo "# (c) 2022-2026 by Walter@Hofstaedtler.com"
        echo "#"
        echo "# How long a Soft deleted message is retained:"
        echo "#SOFTDELETE_RETENTION=70d20h"
        echo "#"
        echo "# How long elements in trash bin are retained:"
        echo "#TRASHBIN_RETENTION=300d10h"
        echo "#"
        echo "# Clean the SYNC_ISSUES/*, 4 folders"
        echo "#MAIL_SYNC=true"
        echo "#"
        echo "# Clean the 'OUTBOX'/'Postausgang' folder (>= 10  min old)"
        echo "#MAIL_OUTBOX=true"
        echo "#"
        echo "# Purge softdelete regarding \$SOFTDELETE_RETENTION"
        echo "#MAIL_SOFT=true"
        echo "#"
        echo "# Purge trashbin regarding \$TRASHBIN_RETENTION"
        echo "#MAIL_TRASH=false"
        echo "#"
        echo "# Purge orphaned data files from mailbox"
        echo "#MAIL_DATA=true"
        echo "#"
        echo "# Vacuum the user database at week day?"
        echo "#MAIL_VACU_DOW=\"6\""
        echo "#"
        echo "# Clean the domain directories / Public store"
        echo "#DOM_DIR=true"
        echo "#"
        echo "# Vacuum the domain databases at week day?"
        echo "#DOM_VACU_DOW=\"X\""
        echo "#"
        echo "# Ignore mailboxes where the email address starts with specific text, such as 'archive_'."
        echo "#IGNORE_MBX=\"archive_\""
        echo "#"
        echo "# Print a warning if the purge process for a mailbox takes longer than nn seconds."
        echo "#WARNING_SEC=120"
        echo "#"
        echo "# Set the periodic start time of the script for the systemd timer."
        echo "#ON_CALENDAR=\"*-*-* 04:04:00\""
        echo "#"
        echo "# Send debug emails."
        echo "#DEBUG_MAIL=\"\""
        echo "#"
        echo "# --- eof ---"
    } > "$sLOCAL_FILE"
    echo
    echo -e "${CYA}2. The override file, $sLOCAL_FILE, has been successfully created. Edit the file as required.${NORM}"
    echo
    # Done
    exit 0
}
#
#
RuntimeFormat() {
    # Calculate the difference between the current time and $iSTART_SECONDS,
    # then print the formatted result.
    # $1 the start time in seconds
    iDURATION=$(( $(date +"%s") - $1 ))
    date -u -d @${iDURATION} +%H:%M:%S
}
#
#
PrintWarning() {
    # Calculate the difference between the current time and $1,
    # if the difference is >= $WARNING_SEC, print the formatted result.
    # $1 the start time in seconds, $2 the mailbox name
    iDURATION=$(( $(date +"%s") - $1 ))
    if [[ iDURATION -ge WARNING_SEC ]]; then
        sMSG="        ${YEL}Warning purge process for $2 needs $(date -u -d @${iDURATION} +%H:%M:%S) ${NORM}"
        logg "$sMSG"
        $bSILENT || echo -e "$sMSG"
    fi
}
#
#
PrintRT() {
    # Calculate the difference between the current time and $1, print the formatted result.
    # $1 the start time in seconds
    iDURATION=$(( $(date +"%s") - $1 ))
    echo -e ", RT: $(date -u -d @${iDURATION} +%H:%M:%S) ${NORM}"
}
#
#
#
# === Main code starts here!
#
# Please note, logging is now in System-D journal: "journalctl -f -t <SCRIPTNAME>"
#
# Mail for debug purpose only
[ -n "$DEBUG_MAIL" ] && echo "${sSCRIPT_NAME} run at $(date +%Y.%m.%d-%H:%M:%S), parameter $*" | /usr/bin/mail -s "${sSCRIPT_NAME} run at $(date +%Y.%m.%d-%H:%M:%S), parameter $*, $(hostname)" "$DEBUG_MAIL"
#
# Get the options
while getopts "htUdsLox" option; do
   case $option in
      h) # Display Help
         bHELP=true;;
      t) # Create systemd timer files
         bCREATE_TIMER=true;;
      U) # Uninstall / remove systemd timer files
         bUNINSTALL_TIMER=true;;
      d) # Enable debug mode
         bDEBUG=true;;
      s) # Enable silence mode
         bSILENT=true;;
      L) # Do NOT write to systemd log
         bLOGSD=true;;
      o) # Create g_cleaner.local overwrite files
         bCREATE_LOCAL=true;;
      x) # Enable bash debug output
         set -x;;
     \?) # Invalid option
         echo -e "${RED}Error: Invalid option: ${YEL}$1${NORM} provided.${NORM}"
         bHELP_ERROR=true;;
         # terminate and indicate error
   esac
done
#
# Sign on message
$bSILENT || echo -e "${YEL}Run gromox-mbop to purge softdelete after ${CYA}$SOFTDELETE_RETENTION${YEL} and cleanup outdated data files.${NORM}"
#
# Repair an empty $IGNORE_MBX variable.
[ -z "$IGNORE_MBX" ] && IGNORE_MBX="@@"
#
# Repair an empty $MAIL_VACU_DOW variable.
[ -z "$MAIL_VACU_DOW" ] && MAIL_VACU_DOW="X"
#
# Repair an empty $DOM_VACU_DOW variable.
[ -z "$DOM_VACU_DOW" ] && DOM_VACU_DOW="X"
#
# Call the functions
$bHELP && Help 0
$bHELP_ERROR && Help 1
$bUNINSTALL_TIMER && UninstallTimer
$bCREATE_TIMER && CreateTimer
$bCREATE_LOCAL && CreateLocal
#
# Find and check the required commands
#   The cleanup tool - "/usr/sbin/gromox-mbop"
GROMOX_MBOP="$(which gromox-mbop 2>/dev/null)"
#   The admin tool -   "usr/sbin/grommunio-admin"
GROMMUNIO_ADMIN="$(which grommunio-admin 2>/dev/null)"
#
for sFILE in "$GROMOX_MBOP" "$GROMMUNIO_ADMIN";
do
    if [ -z "$sFILE" ]; then
        sMSG="${RED}Error: command ${YEL}gromox-mbop${RED} or ${YEL}grommunio-admin${RED} not found, aborting.${NORM}"
        echo -e "$sMSG"
        logg "$sMSG"
        exit 1  # Terminate and indicate error
    fi
done
#
# Get current weekday number (0=Sunday, 6=Saturday)
iCURRENT_DAY=$(date +%w)
#
sMSG="Configurable parameters:"; logg "$sMSG"; $bSILENT || echo -e "$sMSG"
sMSG=" "; logg "$sMSG"; $bSILENT || echo -e "$sMSG"
sMSG="SOFTDELETE_RETENTION : $SOFTDELETE_RETENTION"; logg "$sMSG"; $bSILENT || echo -e "$sMSG"
sMSG="TRASHBIN_RETENTION ..: $TRASHBIN_RETENTION"; logg "$sMSG"; $bSILENT || echo -e "$sMSG"
sMSG="MAIL_SYNC ...........: $MAIL_SYNC"; logg "$sMSG"; $bSILENT || echo -e "$sMSG"
sMSG="MAIL_OUTBOX .........: $MAIL_OUTBOX"; logg "$sMSG";$bSILENT ||  echo -e "$sMSG"
sMSG="MAIL_SOFT ...........: $MAIL_SOFT"; logg "$sMSG"; $bSILENT || echo -e "$sMSG"
sMSG="MAIL_TRASH ..........: $MAIL_TRASH"; logg "$sMSG"; $bSILENT || echo -e "$sMSG"
sMSG="MAIL_DATA ...........: $MAIL_DATA"; logg "$sMSG"; $bSILENT || echo -e "$sMSG"
sMSG="MAIL_VACU_DOW .......: $MAIL_VACU_DOW"; logg "$sMSG"; $bSILENT || echo -e "$sMSG"
sMSG="DOM_DIR .............: $DOM_DIR"; logg "$sMSG"; $bSILENT || echo -e "$sMSG"
sMSG="DOM_VACU_DOW ........: $DOM_VACU_DOW"; logg "$sMSG"; $bSILENT || echo -e "$sMSG"
sMSG="IGNORE_MBX ..........: $IGNORE_MBX"; logg "$sMSG"; $bSILENT || echo -e "$sMSG"
sMSG="WARNING_SEC .........: $WARNING_SEC"; logg "$sMSG"; $bSILENT || echo -e "$sMSG"
sMSG="DEBUG_MAIL ..........: $DEBUG_MAIL"; logg "$sMSG"; $bSILENT || echo -e "$sMSG"
sMSG="iCURRENT_DAY ........: $iCURRENT_DAY"; logg "$sMSG"; $bSILENT || echo -e "$sMSG"
sMSG=" "; logg "$sMSG"; $bSILENT || echo -e "$sMSG"
#

#
# === The working code of this script
#
# Clean the user directories
# Clean SYNC_ISSUES and sub folders.
if $MAIL_SYNC; then
    $bSILENT || echo -e "\n${YEL}Purge SYNC_ISSUES${NORM}, starting: $(date +%Y.%m.%d-%H:%M:%S)"
    iCOUNT=0
    iSKIPPED=0
    iSTART_SECONDS=$(date +"%s")
    mailboxes=$($GROMOX_MBOP foreach.mb echo-username)
    for mailbox in $mailboxes; do
        ((iCOUNT++))
        sCNUM=$(printf "%4d\n" $iCOUNT)
        #
        if [[ ${mailbox,,} =~ ^(${IGNORE_MBX}) ]]; then
            ((iSKIPPED++))
            sMSG="# ${sCNUM}: ${YEL}${mailbox}${NORM}, skipped # ${iSKIPPED}."
            logg "$sMSG"
            $bSILENT || echo -e "$sMSG"
            continue
        fi
        #
        sMSG="# ${sCNUM}: ${CYA}${mailbox}${NORM}"
        #, starting: $(date +%Y.%m.%d-%H:%M:%S)"
        logg "$sMSG"
        $bSILENT || echo -e "$sMSG"
        iWARNING_SECONDS=$(date +"%s")
        for sFOLDER in SYNC_ISSUES CONFLICTS LOCAL_FAILURES SERVER_FAILURES; do
            sMSG="${YEL}        Purge $sFOLDER${NORM}"
            logg "$sMSG"
            $bSILENT || echo -e "$sMSG"
            $bDEBUG && echo "$GROMOX_MBOP -u \"${mailbox}\" emptyfld \"$sFOLDER\""
            sOUTPUT=$($GROMOX_MBOP -u "${mailbox}" emptyfld "$sFOLDER" 2>&1)
            #sOUTPUT="        $sOUTPUT"
            sOUTPUT=$(printf '%s\n' "$sOUTPUT" | sed 's/^/        /')
            logg "$sOUTPUT"
            $bSILENT || echo -e "$sOUTPUT"
        done
        PrintWarning "$iWARNING_SECONDS" "${mailbox}"
    done
    sMSG="${CYA}${iCOUNT} mailboxes processed, ${YEL}${iSKIPPED} of which were skipped,${NORM} end: $(date +%Y.%m.%d-%H:%M:%S), runtime: $(RuntimeFormat "$iSTART_SECONDS").\n"
    logg "$sMSG"
    $bSILENT || echo -e "$sMSG"
fi
#exit 0
#
# Clean the 'OUTBOX'/'Postausgang' folder of elements that are older than 10 min.
if $MAIL_OUTBOX; then
    $bSILENT || echo -e "\n${YEL}Purge OUTBOX${NORM}, starting: $(date +%Y.%m.%d-%H:%M:%S)"
    iCOUNT=0
    iSKIPPED=0
    iSTART_SECONDS=$(date +"%s")
    mailboxes=$($GROMOX_MBOP foreach.mb echo-username)
    for mailbox in $mailboxes; do
        ((iCOUNT++))
        sCNUM=$(printf "%4d\n" $iCOUNT)
        #
        if [[ ${mailbox,,}X =~ ^(${IGNORE_MBX}) ]]; then
            ((iSKIPPED++))
            sMSG="# ${sCNUM}: ${YEL}${mailbox}${NORM}, skipped # ${iSKIPPED}."
            logg "$sMSG"
            $bSILENT || echo -e "$sMSG"
            continue
        fi
        #
        sMSG="# ${sCNUM}: ${CYA}${mailbox}${NORM}, ${YEL}Purge OUTBOX${NORM}"
        #, starting: $(date +%Y.%m.%d-%H:%M:%S)"
        logg "$sMSG"
        $bSILENT || echo -en "$sMSG"
        # Items must be at least 10 minutes old before they can be deleted.
        # We don't want to delete items that are currently being sent. (-t 10min)
        $bDEBUG && echo "$GROMOX_MBOP -u \"${mailbox}\" emptyfld -R --delempty -t 1 OUTBOX"
        iWARNING_SECONDS=$(date +"%s")
        sOUTPUT=$($GROMOX_MBOP -u "${mailbox}" emptyfld -R --delempty -t 10min OUTBOX 2>&1)
        PrintRT iWARNING_SECONDS
        #sOUTPUT="        $sOUTPUT"
        sOUTPUT=$(printf '%s\n' "$sOUTPUT" | sed 's/^/        /')
        logg "$sOUTPUT"
        $bSILENT || echo -e "$sOUTPUT"
        PrintWarning "$iWARNING_SECONDS" "${mailbox}"
        # Wait 1 seconds to get the elements in Softdelete.
        sleep 1
        # Purge Softdelete for Outbox
        sOUTPUT=$($GROMOX_MBOP -u "${mailbox}" purge-softdelete -r -t 0 OUTBOX  2>&1)
        #sOUTPUT="        $sOUTPUT"
        sOUTPUT=$(printf '%s\n' "$sOUTPUT" | sed 's/^/        /')
        logg "$sOUTPUT"
        $bSILENT || echo -e "$sOUTPUT"
    done
    sMSG="${CYA}${iCOUNT} mailboxes processed, ${YEL}${iSKIPPED} of which were skipped,${NORM} end: $(date +%Y.%m.%d-%H:%M:%S), runtime: $(RuntimeFormat "$iSTART_SECONDS").\n"
    logg "$sMSG"
    $bSILENT || echo -e "$sMSG"
fi
#exit 0
#
if $MAIL_SOFT; then
    $bSILENT || echo -e "\n${YEL}Purge softdelete elements after: ${CYA}$SOFTDELETE_RETENTION${NORM}, starting: $(date +%Y.%m.%d-%H:%M:%S)"
    iCOUNT=0
    iSKIPPED=0
    iSTART_SECONDS=$(date +"%s")
    # purge-softdelete, use IPM_SUBTREE for the entire mailbox or DELETED for the recycle bin only.
    mailboxes=$($GROMOX_MBOP foreach.mb echo-username)
    for mailbox in $mailboxes; do
        ((iCOUNT++))
        sCNUM=$(printf "%4d\n" $iCOUNT)
        #
        if [[ ${mailbox,,}X =~ ^(${IGNORE_MBX}) ]]; then
            ((iSKIPPED++))
            sMSG="# ${sCNUM}: ${YEL}${mailbox}${NORM}, skipped # ${iSKIPPED}."
            logg "$sMSG"
            $bSILENT || echo -e "$sMSG"
            continue
        fi
        #
        sMSG="# ${sCNUM}: ${CYA}${mailbox}${NORM}, ${YEL}Purge softdelete${NORM}"
        #, starting: $(date +%Y.%m.%d-%H:%M:%S)"
        logg "$sMSG"
        $bSILENT || echo -en "$sMSG"
        $bDEBUG && echo "$GROMOX_MBOP -u ${mailbox} purge-softdelete -r -t $SOFTDELETE_RETENTION IPM_SUBTREE"
        iWARNING_SECONDS=$(date +"%s")
        sOUTPUT=$($GROMOX_MBOP -u "${mailbox}" purge-softdelete -r -t $SOFTDELETE_RETENTION IPM_SUBTREE 2>&1)
        PrintRT iWARNING_SECONDS
        #sOUTPUT="        $sOUTPUT"
        sOUTPUT=$(printf '%s\n' "$sOUTPUT" | sed 's/^/        /')
        logg "$sOUTPUT"
        $bSILENT || echo -e "$sOUTPUT"
        PrintWarning "$iWARNING_SECONDS" "${mailbox}"
    done
    sMSG="${CYA}${iCOUNT} mailboxes processed, ${YEL}${iSKIPPED} of which were skipped,${NORM} end: $(date +%Y.%m.%d-%H:%M:%S), runtime: $(RuntimeFormat "$iSTART_SECONDS").\n"
    logg "$sMSG"
    $bSILENT || echo -e "$sMSG"
fi
#
if $MAIL_TRASH; then
    $bSILENT || echo -e "\n${YEL}Purge trashbin elements after: ${CYA}$TRASHBIN_RETENTION${NORM}, starting: $(date +%Y.%m.%d-%H:%M:%S)"
    iCOUNT=0
    iSKIPPED=0
    iSTART_SECONDS=$(date +"%s")
    # emptyfld, use DELETED for the recycle bin.
    mailboxes=$($GROMOX_MBOP foreach.mb echo-username)
    for mailbox in $mailboxes; do
        ((iCOUNT++))
        sCNUM=$(printf "%4d\n" $iCOUNT)
        #
        if [[ ${mailbox,,}X =~ ^(${IGNORE_MBX}) ]]; then
            ((iSKIPPED++))
            sMSG="# ${sCNUM}: ${YEL}${mailbox}${NORM}, skipped # ${iSKIPPED}."
            logg "$sMSG"
            $bSILENT || echo -e "$sMSG"
            continue
        fi
        #
        sMSG="# ${sCNUM}: ${CYA}${mailbox}${NORM}, ${YEL}Purge trashbin${NORM}"
        #, starting: $(date +%Y.%m.%d-%H:%M:%S)"
        logg "$sMSG"
        $bSILENT || echo -en "$sMSG"
        $bDEBUG && echo "$GROMOX_MBOP -u ${mailbox} emptyfld -R --delempty --soft -t $TRASHBIN_RETENTION DELETED"
        iWARNING_SECONDS=$(date +"%s")
        sOUTPUT=$($GROMOX_MBOP -u "${mailbox}" emptyfld -R --delempty --soft -t $SOFTDELETE_RETENTION DELETED 2>&1)
        PrintRT iWARNING_SECONDS
        #sOUTPUT="        $sOUTPUT"
        sOUTPUT=$(printf '%s\n' "$sOUTPUT" | sed 's/^/        /')
        logg "$sOUTPUT"
        $bSILENT || echo -e "$sOUTPUT"
        PrintWarning "$iWARNING_SECONDS" "${mailbox}"
    done
    sMSG="${CYA}${iCOUNT} mailboxes processed, ${YEL}${iSKIPPED} of which were skipped,${NORM} end: $(date +%Y.%m.%d-%H:%M:%S), runtime: $(RuntimeFormat "$iSTART_SECONDS").\n"
    logg "$sMSG"
    $bSILENT || echo -e "$sMSG"
fi
#
if $MAIL_DATA; then
    $bSILENT || echo -e "\n${YEL}Purge orphaned data files from mailbox${NORM}, starting: $(date +%Y.%m.%d-%H:%M:%S)"
    iCOUNT=0
    iSKIPPED=0
    iSTART_SECONDS=$(date +"%s")
    mailboxes=$($GROMOX_MBOP foreach.mb echo-username)
    for mailbox in $mailboxes; do
        ((iCOUNT++))
        sCNUM=$(printf "%4d\n" $iCOUNT)
        #
        if [[ ${mailbox,,}X =~ ^(${IGNORE_MBX}) ]]; then
            ((iSKIPPED++))
            sMSG="# ${sCNUM}: ${YEL}${mailbox}${NORM}, skipped # ${iSKIPPED}."
            logg "$sMSG"
            $bSILENT || echo -e "$sMSG"
            continue
        fi
        #
        sMSG="# ${sCNUM}: ${CYA}${mailbox}${NORM}, ${YEL}Purge mailbox${NORM}"
        #, starting: $(date +%Y.%m.%d-%H:%M:%S)"
        logg "$sMSG"
        $bSILENT || echo -en "$sMSG"
        $bDEBUG && echo "$GROMOX_MBOP -u ${mailbox} purge-datafiles"
        iWARNING_SECONDS=$(date +"%s")
        sOUTPUT=$($GROMOX_MBOP -u "${mailbox}" purge-datafiles 2>&1)
        PrintRT iWARNING_SECONDS
        if [[ $sOUTPUT -ge 5 ]]; then
            #sOUTPUT="        $sOUTPUT"
            sOUTPUT=$(printf '%s\n' "$sOUTPUT" | sed 's/^/        /')
            $bSILENT || echo -e "$sOUTPUT"
        fi
        PrintWarning "$iWARNING_SECONDS" "${mailbox}"
    done
    sMSG="${CYA}${iCOUNT} mailboxes processed, ${YEL}${iSKIPPED} of which were skipped,${NORM} end: $(date +%Y.%m.%d-%H:%M:%S), runtime: $(RuntimeFormat "$iSTART_SECONDS").\n"
    logg "$sMSG"
    $bSILENT || echo -e "$sMSG"
fi
#
#if [[ " $MAIL_VACU_DOW " =~ [[:space:]]${iCURRENT_DAY}[[:space:]] ]]; then
if [[ ${iCURRENT_DAY} =~ ($MAIL_VACU_DOW) ]]; then
    # Mail for debug purpose only
    [ -n "$DEBUG_MAIL" ] && echo "${sSCRIPT_NAME} - MAIL_VACU_DOW run at $(date +%Y.%m.%d-%H:%M:%S)" | /usr/bin/mail -s "${sSCRIPT_NAME} - \$MAIL_VACU_DOW: ${MAIL_VACU_DOW}=${iCURRENT_DAY} run at $(date +%Y.%m.%d-%H:%M:%S), $(hostname)" "$DEBUG_MAIL"
    $bSILENT || echo -e "\n${YEL}Vacuum the user mailbox database${NORM}, starting: $(date +%Y.%m.%d-%H:%M:%S)"
    iCOUNT=0
    iSKIPPED=0
    iSTART_SECONDS=$(date +"%s")
    mailboxes=$($GROMOX_MBOP foreach.mb echo-username)
    for mailbox in $mailboxes; do
        ((iCOUNT++))
        sCNUM=$(printf "%4d\n" $iCOUNT)
        #
        if [[ ${mailbox,,}X =~ ^(${IGNORE_MBX}) ]]; then
            ((iSKIPPED++))
            sMSG="# ${sCNUM}: ${YEL}${mailbox}${NORM}, skipped # ${iSKIPPED}."
            logg "$sMSG"
            $bSILENT || echo -e "$sMSG"
            continue
        fi
        #
        sMSG="# ${sCNUM}: ${CYA}${mailbox}${NORM}, ${YEL}Vacuum user mailbox database${NORM}"
        #, starting: $(date +%Y.%m.%d-%H:%M:%S)"
        logg "$sMSG"
        $bSILENT || echo -en "$sMSG"
        $bDEBUG && echo "$GROMOX_MBOP -u ${mailbox} vacuum"
        iWARNING_SECONDS=$(date +"%s")
        sOUTPUT=$($GROMOX_MBOP -u "${mailbox}" vacuum 2>&1)
        PrintRT iWARNING_SECONDS
        if [[ $sOUTPUT -ge 5 ]]; then
            #sOUTPUT="        $sOUTPUT"
            sOUTPUT=$(printf '%s\n' "$sOUTPUT" | sed 's/^/        /')
            logg "$sOUTPUT"
            $bSILENT || echo -e "$sOUTPUT"
        fi
        PrintWarning "$iWARNING_SECONDS" "${mailbox}"
    done
    sMSG="${CYA}${iCOUNT} mailboxes processed, ${YEL}${iSKIPPED} of which were skipped,${NORM} end: $(date +%Y.%m.%d-%H:%M:%S), runtime: $(RuntimeFormat "$iSTART_SECONDS").\n"
    logg "$sMSG"
    $bSILENT || echo -e "$sMSG"
fi
#
$bSILENT || echo -e "\n${YEL}Recalculates the store size for mailboxes${NORM}, starting: $(date +%Y.%m.%d-%H:%M:%S)"
iCOUNT=0
iSKIPPED=0
iSTART_SECONDS=$(date +"%s")
mailboxes=$($GROMOX_MBOP foreach.mb echo-username)
for mailbox in $mailboxes; do
    ((iCOUNT++))
    sCNUM=$(printf "%4d\n" $iCOUNT)
    #
    sMSG="# ${sCNUM}: ${CYA}${mailbox}${NORM}, ${YEL}Recalculates the store size${NORM}"
    logg "$sMSG"
    $bSILENT || echo -en "$sMSG"
    $bDEBUG && echo "$GROMOX_MBOP -u ${mailbox} recalc-sizes"
    iWARNING_SECONDS=$(date +"%s")
    sOUTPUT=$($GROMOX_MBOP -u "${mailbox}" recalc-sizes 2>&1)
    PrintRT iWARNING_SECONDS
    sOUTPUT=$(printf '%s\n' "$sOUTPUT" | sed 's/^/        /')
    $bSILENT || echo -e "$sOUTPUT"
    PrintWarning "$iWARNING_SECONDS" "${mailbox}"
done
sMSG="${CYA}${iCOUNT} mailboxes processed,${NORM} end: $(date +%Y.%m.%d-%H:%M:%S), runtime: $(RuntimeFormat "$iSTART_SECONDS").\n"
logg "$sMSG"
$bSILENT || echo -e "$sMSG"
#
if $DOM_DIR; then
    $bSILENT || echo -e "\n${YEL}Clean the domain directories${NORM}, starting: $(date +%Y.%m.%d-%H:%M:%S)"
    iCOUNT=0
    iSTART_SECONDS=$(date +"%s")
    domains=$($GROMMUNIO_ADMIN domain query domainname domainStatus | grep "0/active" | awk '{ print $1 }')
    for domain in $domains; do
        ((iCOUNT++))
        sCNUM=$(printf "%4d\n" $iCOUNT)
        sMSG="# ${sCNUM}: ${CYA}${domain}${NORM}, ${YEL}Purge Public Store${NORM}"
        #, starting: $(date +%Y.%m.%d-%H:%M:%S)"
        logg "$sMSG"
        $bSILENT || echo -en "$sMSG"
        $bDEBUG && echo "$GROMOX_MBOP -u @${domain} purge-datafiles"
        iWARNING_SECONDS=$(date +"%s")
        sOUTPUT=$($GROMOX_MBOP -u "@${domain}" purge-datafiles 2>&1)
        PrintRT iWARNING_SECONDS
        if [[ $sOUTPUT -ge 5 ]]; then
            #sOUTPUT="        $sOUTPUT"
            sOUTPUT=$(printf '%s\n' "$sOUTPUT" | sed 's/^/        /')
            logg "$sOUTPUT"
            $bSILENT || echo -e "$sOUTPUT"
        fi
        PrintWarning "$iWARNING_SECONDS" "${domain}"
    done
    sMSG="${CYA}${iCOUNT} domains processed,${NORM} end: $(date +%Y.%m.%d-%H:%M:%S), runtime: $(RuntimeFormat "$iSTART_SECONDS").\n"
    logg "$sMSG"
    $bSILENT || echo -e "$sMSG"
fi
#
#if [[ " $DOM_VACU_DOW " =~ [[:space:]]${iCURRENT_DAY}[[:space:]] ]]; then
if [[ ${iCURRENT_DAY} =~ ($DOM_VACU_DOW) ]]; then
    # Mail for debug purpose only
    [ -n "$DEBUG_MAIL" ] && echo "${sSCRIPT_NAME} - DOM_VACU_DOW run at $(date +%Y.%m.%d-%H:%M:%S)" | /usr/bin/mail -s "${sSCRIPT_NAME} - \$DOM_VACU_DOW: ${DOM_VACU_DOW}=${iCURRENT_DAY} run at $(date +%Y.%m.%d-%H:%M:%S), $(hostname)" "$DEBUG_MAIL"
    $bSILENT || echo -e "\n${YEL}Vacuum the domain databases${NORM}"
    iCOUNT=0
    iSTART_SECONDS=$(date +"%s")
    domains=$($GROMMUNIO_ADMIN domain query domainname domainStatus | grep "0/active" | awk '{ print $1 }')
    for domain in $domains; do
        ((iCOUNT++))
        sCNUM=$(printf "%4d\n" $iCOUNT)
        sMSG="# ${sCNUM}: ${CYA}${domain}${NORM}, ${YEL}Vacuum the domain database${NORM}"
        #, starting: $(date +%Y.%m.%d-%H:%M:%S)"
        logg "$sMSG"
        $bSILENT || echo -en "$sMSG"
        $bDEBUG && echo "$GROMOX_MBOP -u @${domain} vacuum"
        iWARNING_SECONDS=$(date +"%s")
        sOUTPUT=$($GROMOX_MBOP -u "@${domain}" purge-datafiles 2>&1)
        PrintRT iWARNING_SECONDS
        if [[ $sOUTPUT -ge 5 ]]; then
            #sOUTPUT="        $sOUTPUT"
            sOUTPUT=$(printf '%s\n' "$sOUTPUT" | sed 's/^/        /')
            logg "$sOUTPUT"
            $bSILENT || echo -e "$sOUTPUT"
        fi
        PrintWarning "$iWARNING_SECONDS" "${domain}"
    done
    sMSG="${CYA}${iCOUNT} domains processed,${NORM} end: $(date +%Y.%m.%d-%H:%M:%S), runtime: $(RuntimeFormat "$iSTART_SECONDS").\n"
    logg "$sMSG"
    $bSILENT || echo -e "$sMSG"
fi
#
sMSG="${CYA}Script run time:${NORM} $(date -u -d @${SECONDS} +%H:%M:%S).\n"
logg "$sMSG"
$bSILENT || echo -e "$sMSG"
# --- eof ---
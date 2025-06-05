#!/bin/bash
#
# Check or repair all mailboxes with cgkrepair.
#
# Script to check or repair ICS properties in all mailboxes. In some cases
# flags like read/unread, forwarded, answered, categories etc. are not 
# processed when these errors are present in a mailbox.
#
# First, run this script without parameters, only if you see messages like:
#
#   message 6f5824h [--P]
#   message 6f5829h [--P]
#   message 6f5847h [-NP]
#   message 6f590eh [-NP]
#   message 6f59a1h [-NP]
#   folder ah [--P]
#   folder 524466h [--P]
#
# Run the script with the -f parameter to fix the problems.
#
#
# (c) 2025 by Walter@Hofstaedtler.com
#
# 28.04.2025 WH, V 1.0, First release
#
#
# Installation:
# 1. Place this script in /scripts/manual/ as g_cgkrepair.sh
# 2. Convert the script to Linux LF with:
#    dos2unix /scripts/manual/g_cgkrepair.sh
# 3. Make the script executable with:
#    chmod +x /scripts/manual/g_cgkrepair.sh
#
# Run the script and specify the required parameter, just -f.
#
#
CYA="\033[0;36m"; YEL="\033[0;33m"; NORM="\033[0m" BLUE="\033[0;34m" RED="\033[0;31m"
log="/tmp/g_cgkrepair.log"
repair=false
quiet=false
verbose=false
dry_run="-n"
count=0
err_dir=0
errors=0
#
OPTIND=1
while getopts ":fqv" opt; do
    case $opt in
        f) repair=true;;
	q) quiet=true;;
        v) verbose=true;;
        *) ;;
    esac
done
shift $((OPTIND - 1))

if $quiet; then
	#exec 1>> >(ts '[%Y-%m-%d %H:%M:%.S]' >> "$log") 2>&1	
	exec 1>> >(sed -e 's/\x1b\[[0-9;]*m//g' >> "$log") 2>&1
fi
logg() { sed -e 's/\x1b\[[0-9;]*m//g' >> "$log"; }

MSGT="Check"
MSGL=$MSGT
echo
echo -e "${CYA}Checks or repairs all grommunio mailboxes on this system with cgkrepair.${NORM}"
echo -e "  Use the ${YEL}-f${NORM} parameter to start the repair."
echo -e "  Without -f the mailbox will only be checked (dry run)."
echo -e "  Use ${YEL}-v${NORM} to be verbose."
echo -e "  Use ${RED}-q${NORM} to be quiet (the log will still be filled)."
if $repair; then
    echo -e "${YEL}-f is set, repair all mailboxes ...${NORM}"
    MSGT="${YEL}Repair"
    MSGL="Repair"
    dry_run=""
fi
echo
echo "Script $0 started at: $(date +%Y%m%d-%H%M%S)" >"$log"
#
# Read all mailboxes in a variable
mailboxes=$(grommunio-admin user query username maildir | grep "/user/" | grep "@" | awk '{print $1}')

# Now iterate through all mailboxes
# shellcheck disable=SC2068
for mailbox in ${mailboxes[@]}; do
    entries=
    output=
    maildir=$(gromox-mbop -u "$mailbox" echo-maildir)
    count=$((count +1))
    if ! [ -d "$maildir" ]; then
	    echo "Error: No Maildir/Access: $mailbox" |tee /dev/stderr |tee >(logg)
	err_dir=$((err_dir +1))
        continue
    fi
    
    echo -e "$MSGT mailbox # ${count}: ${CYA}$mailbox${NORM} ... " |tee >(logg)
 
    # shellcheck disable=SC2086
    output=$(/usr/libexec/gromox/cgkrepair $dry_run -e "$mailbox" | tee -a "$log")
    if [[ $? -ne 0 ]]; then
        errors=$((errors +1))
        echo -e "${RED}Error found!${NORM}" |tee /dev/stderr |tee >(logg)
    fi
    if [ -n "$output" ]; then
        entries=$(grep -c 'message' <<< "$output")
        if [ -n "$entries" ]; then
            entries=${#output}
	    echo -e "${RED}Found $entries problematic objects.${NORM}" |tee >(logg)
        fi
        if $verbose; then
            echo -e "${BLUE}Verbose mode active. Dumping result:${NORM}" |tee >(log)
            echo "$output"
        fi
    else
        echo "No problematic objects detected." |tee >(log)
    fi
    echo
    #
done
echo -e "${CYA}${count} mailboxes checked.${NORM}" |tee >(log)
# check errors
if [[ $errors -gt 0 ]]; then
    echo -e "${RED}$errors errors encountered!${NORM}" |tee /dev/stderr |tee >(logg)
fi
# directory not found errors
if [[ $err_dir -gt 0 ]]; then
    echo -e "${RED}$err_dir directories not found!${NORM}" |tee /dev/stderr |tee >(logg)
fi
echo -e "The log file is: $log"
$repair && echo -e "${CYA}Please note: Run the script until no more errors occur.${NORM}" |tee >(log)
#
echo "Script $0 stopped at: $(date +%Y%m%d-%H%M%S%n)" >> "$log"

#
# eof
#

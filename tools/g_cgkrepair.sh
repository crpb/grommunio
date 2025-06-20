#!/usr/bin/env bash
#set -e
#
set -o pipefail
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
# (c) 2025 by Walter@Hofstaedtler.com,
#             christopher@bocki.com
#
# 28.04.2025 WH,   V 1.0, First release
# 05.06.2025 CRPB, V 1.1, Enhancements
# 14.06.2025 CRPB, V 1.2, Enhancements
# 15.06.2025 WH,   V 1.3, Enhancements
# 20.06.2025 WH,   V 1.4, Count the mailboxes with errors and improve the formatting
# 20.06.2025 WH,   V 1.5, Improve the formatting
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
log='/tmp/g_cgkrepair.log'
quiet=false
repair=false
silent=false
verbose=false
dry_run='-n'
count=0
err_dir=0
errors=0
#
BLUE='\033[0;34m'
CYA='\033[0;36m'
NORM='\033[0m'
RED='\033[0;31m'
YEL='\033[0;33m'

showhelp() {
  echo -e "${CYA}Checks or repairs all grommunio mailboxes on this system with cgkrepair.${NORM}"
  echo -e "  Use the ${YEL}-f${NORM} parameter to start the repair."
  echo -e "  Without -f the mailbox will only be checked (dry run)."
  echo -e "  Use ${YEL}-v${NORM} to be verbose, show test and repair results."
  echo -e "  Use ${CYA}-s${NORM} to only show defective mailboxes."
  echo -e "  Use ${RED}-q${NORM} to be quiet (the log will still be filled)."
  echo -e "  Use -l path/to/file to use another logfile than the default /tmp/g_ckgrepair.log."
  echo -e "  Use -e user@domain.tld to only run check/fix for one user.\n"
}


#OPTIND=1
while getopts hfsqve:l: opts; do
    case "${opts}" in
        e) email="${OPTARG:?}"
             ;;
        f) repair=true
           ;;
        h) showhelp
           exit 0
           ;;
        l) if touch -c "$OPTARG" 2>/dev/null; then
               log="${OPTARG:?}"
            else
               exit 77
           fi
           ;;
        q) quiet=true
           ;;
        s) silent=true
           ;;
        v) verbose=true
           ;;
        ?) showhelp
           exit 1
           ;;
    esac
done
shift $((OPTIND - 1))

#[ "$#" -eq 0 ] && showhelp

if $quiet; then
    # Redirects all output (stdout and stderr)
    exec 3>&1 4>&2 1>/dev/null 2>&4
fi
# Removes ANSI color escape codes and writes to the log file
logg() { sed -e 's/\x1b\[[0-9;]*m//g' >> "$log"; }

MSGT="Check"

if $repair; then
    echo -e "${YEL}-f is set, repair all mailboxes ...${NORM}"
    MSGT="${YEL}Repair"
    dry_run=""
fi
# We append to an existing log
echo "Script $0 started at: $(date -Im)" >>"$log"
#
# If -e usr@dom.tld was supplied
[ -n "$email" ] && mailboxes=$email
# Read all mailboxes in a variable
[ -z "$email" ] && mailboxes=$(gromox-mbop foreach.mb echo-username)

# Now iterate through all mailboxes
# shellcheck disable=SC2068
for mailbox in $mailboxes; do
    entries=
    output=
    maildir=$(gromox-mbop -u "$mailbox" echo-maildir)
    count=$((count +1))
    if ! [ -d "$maildir" ]; then
        echo "Error: No Maildir/Access: $mailbox" |tee /dev/stderr |tee >(logg)
    err_dir=$((err_dir +1))
        continue
    fi

    fnum=$(printf "%4d\n" $count)
    $silent || echo -e "$MSGT mailbox # ${fnum}: ${CYA}$mailbox${NORM} ... " |tee >(logg)

    # shellcheck disable=SC2086
    output=$(/usr/libexec/gromox/cgkrepair $dry_run -e "$mailbox" | tee -a "$log")
    ret=$?
    if [[ $ret -ne 0 ]]; then
        errors=$((errors +1))
        echo -e "${RED}Error occurred while repairing $mailbox!${NORM}" |tee /dev/stderr |tee >(logg)
        $silent || echo -e "$MSGT mailbox # ${count}: ${CYA}$mailbox${NORM} ... " |tee >(logg)
    fi
    if [ -n "$output" ]; then

        if [ -n "$entries" ]; then
            entries=${#output}
            # Count the mailboxes with errors
            errors=$((errors +1))
            $silent && echo -e "$MSGT mailbox # ${count}: ${CYA}$mailbox${NORM} ... " |tee >(logg)
            echo -ne "${RED}*****                 Found $entries problematic objects.${NORM}\n" |tee >(logg)
        fi
        if $verbose; then
            echo -e "${BLU}Verbose mode active. Dumping result:${NORM}" |tee >(logg)
            echo "$output"
        fi
    else
        $verbose && echo -e "No problematic objects detected.\n" |tee >(logg)
    fi
    #
done
fnum=$(printf "%4d\n" $count)
echo -e "       ${CYA}${fnum} mailboxes checked.${NORM}" |tee >(logg)
# check errors
if [[ $errors -gt 0 ]]; then
    fnum=$(printf "%4d\n" $errors)
    echo -e "${RED}*****  ${fnum} mailboxes with errors were found!${NORM}" |tee >(logg)
    $quiet && echo -e "${RED}*****  ${fnum} mailboxes with errors were found!${NORM}" /dev/stderr
fi
# directory not found errors
if [[ $err_dir -gt 0 ]]; then
    fnum=$(printf "%4d\n" $err_dir)
    echo -e "${RED}*****  ${fnum} directories not found!${NORM}" |tee >(logg)
    $quiet && echo -e "${RED}*****  ${fnum} directories not found!${NORM}" /dev/stderr
fi
  echo -e "The log file is: $log"
  $repair && echo -e "${CYA}Please note: Run the script until no more errors occur.${NORM}" |tee >(logg)
  #
echo -e "Script $0 stopped at: $(date -Im)\n" >> "$log"
#
# eof
#

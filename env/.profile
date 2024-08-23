# Sample .profile for SuSE Linux
# rewritten by Christian Steinruecken <cstein@suse.de>
#
# This file is read each time a login shell is started.
# All other interactive shells will only read .bashrc; this is particularly
# important for language settings, see below.

test -z "$PROFILEREAD" && . /etc/profile || true

# Most applications support several languages for their output.
# To make use of this feature, simply uncomment one of the lines below or
# add your own one (see /usr/share/locale/locale.alias for more codes)
# This overwrites the system default set in /etc/sysconfig/language
# in the variable RC_LANG.
#
#export LANG=de_DE.UTF-8	# uncomment this line for German output
#export LANG=fr_FR.UTF-8	# uncomment this line for French output
#export LANG=es_ES.UTF-8	# uncomment this line for Spanish output

if [ -d "$HOME/.local/bin" ] ; then
      PATH="$HOME/.local/bin/:$PATH"
fi
# Some people don't like fortune. If you uncomment the following lines,
# you will have a fortune each time you log in ;-)

#if [ -x /usr/bin/fortune ] ; then
#    echo
#    /usr/bin/fortune
#    echo
#fi
smtpauths=$(journalctl --unit postfix.service --since=-7days | sed -n '/sasl_method/ s/.*client=\(.*\)\[\(.*\)\],.*sasl_username=\(.*\)$/\3 \2 \1/p' |sort | uniq -c |sort -nr)
if [[ "${#smtpauths}" -gt 0 ]]; then
  echo "SMTP-Logins in the last 7 days"
  echo "$smtpauths"
fi
source ~/.bashrc

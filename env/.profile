test -z "$PROFILEREAD" && . /etc/profile || true

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
if [ -d "$HOME/bin" ] ; then
      PATH="$HOME/bin:$PATH"
fi
if [ -d "$HOME/.local/bin" ] ; then
      PATH="$HOME/.local/bin/:$PATH"
fi
export PATH
if [ -t 1 ] ; then
	smtpauths=$(journalctl --unit postfix.service --since=-7days |
		sed -n '/sasl_method/ s/.*client=\(.*\)\[\(.*\)\],.*sasl_username=\(.*\)$/\3 \2 \1/p' |
		sort | uniq -c |sort -nr)
	if [[ "${#smtpauths}" -gt 0 ]]; then
		echo "SMTP-Logins in the last 7 days"
		echo "$smtpauths"
	fi
	_failed="$(systemctl --failed --no-pager --legend=no)"
	if [ -n "$_failed" ]; then
		red 'FAILED SERVICES'
		yellow "$_failed"
	fi
	unset _failed
fi



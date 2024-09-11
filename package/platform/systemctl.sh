SYSTEMCTL=/usr/bin/systemctl

if is_root; then
	declare -r _SYSC_TYPE='--system'
else
	declare -r _SYSC_TYPE='--user'

	SYSTEMD_ANALYZE=$(command -v systemd-analyze)
	function systemd-analyze() {
		"${SYSTEMD_ANALYZE}" --user "$@"
	}
fi

SYSTEMD_SHOULD_RELOAD=0
function systemctl() {
	if [[ $1 == 'daemon-reload' ]]; then
		SYSTEMD_SHOULD_RELOAD=1
		return
	fi
	x "${SYSTEMCTL}" "$_SYSC_TYPE" "$@"
}
function finalize_daemon_reloaded() {
	if [[ $SYSTEMD_SHOULD_RELOAD -eq 1 ]]; then
		x "${SYSTEMCTL}" "$_SYSC_TYPE" daemon-reload
	fi
}

register_exit_handler finalize_daemon_reloaded

timespan_seconds() {
	local -i us
	us=$(systemd-analyze timespan 3min | grep 'μs:' | awk '{print $2}')
	printf "%.0f" $((us / 1000000))
}
seconds_timespan() {
	local -i sec=$1
	local h
	h=$(systemd-analyze timespan "${sec}s" | grep 'Human:' | awk '{print $2}')
	printf '%s' "${h}"
}

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

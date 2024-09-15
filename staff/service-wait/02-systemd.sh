function self_journal() {
	journalctl "_SYSTEMD_INVOCATION_ID=${INVOCATION_ID}" -f 2>&1
}
function expand_timeout() {
	if [[ $1 -gt 0 ]]; then
		sdnotify "EXTEND_TIMEOUT_USEC=$1"
	fi
}
function expand_timeout_seconds() {
	if [[ $1 -gt 0 ]]; then
		sdnotify "EXTEND_TIMEOUT_USEC=$(($1 * 1000000 + 5000))"
	fi
}

function startup_done() {
	sdnotify --ready --status=ok
	info_log "Finish, Ok."
	sleep 10
	exit 0
}
info_log "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR-*missing*}"
function systemctl() {
	if [[ -z ${XDG_RUNTIME_DIR-} ]] || [[ $XDG_RUNTIME_DIR == */0 ]]; then
		/usr/bin/systemctl "$@"
	else
		/usr/bin/systemctl --user "$@"
	fi
}
function journalctl() {
	if [[ -z ${XDG_RUNTIME_DIR-} ]] || [[ $XDG_RUNTIME_DIR == */0 ]]; then
		/usr/bin/journalctl "$@"
	else
		/usr/bin/journalctl --user "$@"
	fi
}

declare -i SERVICE_START_TIMEOUT_SEC=0
function get_service_property() {
	systemctl show "${UNIT_NAME}" "--property=$1" --value
}

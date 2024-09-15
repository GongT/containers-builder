_CURRENT_INDENT='{srv-wait} '

function critical_die() {
	info_error "$*"
	exit 233
}
function die() {
	info_error "$*"
	exit 1
}

function try_resolve_file() {
	local i PATHS=(
		"$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
		"$(pwd)"
	)
	for i in "${PATHS[@]}"; do
		if [[ -f "${i}/$1" ]]; then
			realpath -m "${i}/$1"
			return
		fi
	done
	printf "%s" "$1"
}

function _on_exit_notify_service_manager() {
	local EXIT_CODE=$?
	set +Eeuo pipefail
	sdnotify --stopping "--status=control process $$ exit"
	callstack 2
	critical_die "startup script died with error code ${EXIT_CODE}"
}

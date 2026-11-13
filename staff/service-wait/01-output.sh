_CURRENT_INDENT='{srv-wait} '

function critical_die() {
	info_error "$*"
	exit 233
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
	sdnotify --stopping "--status=控制进程 $$ 退出"
	callstack 2
	critical_die "服务主启动进程异常退出, 错误码为 ${EXIT_CODE}"
}

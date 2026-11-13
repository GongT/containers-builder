function wait_by_sleep() {
	local -r WAIT_TIME=$1
	local -i I

	for ((I = WAIT_TIME; I > 0; I--)); do
		sdnotify --status="等待秒数: ${I}/${WAIT_TIME}"
		sleep 1
	done

	wait_for_conmon_start

	echo "看到主进程 PID: $PID"
	if ! grep -q 'conmon' "/proc/${PID}/cmdline"; then
		if [[ -e "/proc/${PID}" ]]; then
			echo "命令行: $(tr '' '' <"/proc/${PID}/cmdline")" >&2
		else
			echo "进程 ${PID} 不存在" >&2
		fi
		return 1
	fi
	service_wait_success
}

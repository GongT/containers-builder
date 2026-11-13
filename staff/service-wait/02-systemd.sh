function self_journal() {
	journalctl "_SYSTEMD_INVOCATION_ID=${INVOCATION_ID}" -f 2>&1
}

function startup_done() {
	sdnotify --ready --status=ok
	info_log "服务主启动进程成功完成"
	sleep 10
	exit 0
}
info_log "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR-*missing*}"

declare -i SERVICE_START_TIMEOUT_SEC=0

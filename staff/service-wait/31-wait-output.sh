function wait_by_output() {
	local WAIT_OUTPUT=$1

	sdnotify --status="等待journal输出..."

	self_journal | while read -r line; do
		if [[ ${line} == *SDNOTIFY* ]]; then
			continue
		elif echo "${line}" | grep -qE "${WAIT_OUTPUT}"; then
			info_log "== ---- 发现预期的输出 ---- =="
			service_wait_success
			return 0
		fi

		# expand_timeout_seconds "5"
	done
}

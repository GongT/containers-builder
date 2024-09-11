#!/usr/bin/env bash
set -Eeuo pipefail

function wait_by_sleep() {
	local -r WAIT_TIME=$1
	local -i I

	for ((I = WAIT_TIME; I > 0; I--)); do
		sdnotify --status="wait:${I}/${WAIT_TIME}"
		sleep 1
	done

	local PID
	PID=$(get_service_property "MainPID")
	if [[ ${PID} -le 0 ]]; then
		die "main pid is invalid."
	fi

	echo "see main pid is $PID"
	if ! grep -q 'conmon' "/proc/${PID}/cmdline"; then
		if [[ -e "/proc/${PID}" ]]; then
			echo "commandline: $(tr '' '' <"/proc/${PID}/cmdline")" >&2
		else
			echo "process ${PID} not exists" >&2
		fi
		return 1
	fi
}

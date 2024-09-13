#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit extglob nullglob globstar lastpipe shift_verbose

function sleep_out() {
	for ((i = $1; i > 0; i--)); do
		echo "sleep: ${i}"
		sleep 1
	done
}

function success() {
	sleep_out 10
	echo "check is success"
	exit 0
}
function failure() {
	sleep_out 10
	echo "check is failure"
	exit 123
}

echo "this is health check"
success

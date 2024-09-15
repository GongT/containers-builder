#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit extglob nullglob globstar lastpipe shift_verbose

echo "called script with args: $*"

function sleep_out() {
	for ((i = $1; i > 0; i--)); do
		echo "sleep: ${i}"
		sleep 1
	done
}

if [[ $* == stop ]]; then
	sleep_out 5
	echo "sigterm send to 1"
	kill -s sigterm 1
else
	sleep_out 10
	echo "reload success"
fi

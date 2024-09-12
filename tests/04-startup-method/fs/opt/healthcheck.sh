#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit extglob nullglob globstar lastpipe shift_verbose

function success() {
	sleep 2
	echo "check is success"
	exit 0
}
function failure() {
	sleep 2
	echo "check is failure"
	exit 123
}

echo "this is health check"
success

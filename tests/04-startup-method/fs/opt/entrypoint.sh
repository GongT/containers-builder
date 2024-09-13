#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit extglob nullglob globstar lastpipe shift_verbose

trap "echo 'exit trap called'; exit 0" EXIT
trap "echo 'got sigint'; exit 0" SIGINT

function echo() {
	printf '\e[38;5;9m%s\e[0m\n' "$*"
}

function sleep_out() {
	for ((i = $1; i > 0; i--)); do
		echo "sleep: ${i}"
		sleep 1
	done
}

WANT_MESSAGE="success when see this message"
WANT_FILE="/some/file/in/container"
WANT_PORT=12345
WANT_SOCKET=/run/sockets/the-socket.sock

case "${1-}" in
sleep)
	echo "will quit after 15s"
	sleep_out 15
	exit 0
	;;
output)
	echo "will print message after 15s"
	sleep_out 5
	echo "this is your message: ${WANT_MESSAGE}"
	;;
touch)
	echo "will touch $STARTUP_TOUCH_FILE after 10s"
	sleep_out 10
	mkdir -p "$(dirname "${STARTUP_TOUCH_FILE}")"
	echo "hello" >"${STARTUP_TOUCH_FILE}"
	;;
port)
	echo "will listen udp $WANT_PORT after 10s"
	sleep_out 10
	ncat -kuvvl --sh-exec cat 0.0.0.0 "${WANT_PORT}"
	;;
socket)
	echo "will listen udp $WANT_SOCKET after 10s"
	sleep_out 10
	socat "UNIX-LISTEN:${WANT_SOCKET},fork" EXEC:/bin/cat
	;;
healthy)
	echo "will healthy logic in other file"
	;;
*)
	echo "unknown method: $*"
	exit 233
	;;
esac

while true; do
	sleep 5s
done

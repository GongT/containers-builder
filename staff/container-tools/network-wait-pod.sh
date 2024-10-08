#!/usr/bin/env bash

# shellcheck source=../../package/include.sh
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/service-library.sh"

declare -r NAME="$1"

if podman pod exists "${NAME}"; then
	echo "pod ${NAME} is running." >&2
	exit 0
fi

declare -r START_TIMEOUT=3min

START_TIMEOUT_SEC=$(timespan_seconds "${START_TIMEOUT}")
start_time=$(uptime_sec)
declare -ir start_time START_TIMEOUT_SEC
declare -i now_time delta_sec

echo "waitting pod ${NAME} to be running..." >&2
while ! podman pod exists "$1"; do
	now_time=$(uptime_sec)
	delta_sec=$((now_time - start_time))
	if [[ ${delta_sec} -gt ${START_TIMEOUT_SEC} ]]; then
		echo "pod ${NAME} is not running!" >&2
		exit 233
	fi

	spend=$(seconds_timespan "${delta_sec}")
	sdnotify "--status=wait pod ${NAME} [${spend}/${START_TIMEOUT}]" "EXTEND_TIMEOUT_USEC=5000000"
	sleep 5
done

echo "pod ${NAME} is running!" >&2

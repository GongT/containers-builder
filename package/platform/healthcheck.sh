#!/usr/bin/env bash

# healthcheck interval retry CMD...
function healthcheck() {
	if [[ $1 == "none" || $1 == "NONE" ]]; then
		__healthcheck_reset
		HEALTHCHECK_CMD=("none")
		return
	fi
	HEALTHCHECK_CMD=("$@")
}

function healthcheck_interval() {
	HEALTHCHECK_INTERVAL="$(timespan_seconds "$1")"
}
function healthcheck_retry() {
	HEALTHCHECK_RETRY="$1"
}
function healthcheck_timeout() {
	HEALTHCHECK_TIMEOUT="$(timespan_seconds "$1")"
}

function healthcheck_startup() {
	HEALTHCHECK_START_PERIOD="$(timespan_seconds "$1")"
	HEALTHCHECK_START_INTERVAL="$(timespan_seconds "$1")"
}

function __healthcheck_reset() {
	declare -gi HEALTHCHECK_INTERVAL=0
	declare -gi HEALTHCHECK_RETRY=0
	declare -ga HEALTHCHECK_CMD=()
	declare -gi HEALTHCHECK_START_INTERVAL=0
	declare -gi HEALTHCHECK_START_PERIOD=0
	declare -gi HEALTHCHECK_TIMEOUT=0
}
register_unit_reset __healthcheck_reset

function __healthcheck_config() {
	if [[ ${#HEALTHCHECK_CMD[@]} -eq 0 ]]; then
		return
	fi

	if [[ ${HEALTHCHECK_CMD[0]} == "none" ]]; then
		# add_build_config "--healthcheck=NONE"
		add_build_config "--annotation=healthcheck=$(json_array "--healthcheck=NONE")"
		add_run_argument "--health-cmd=none"
		return
	fi

	local HEALTHCHECK_DATA=()

	# add_build_config "--healthcheck=CMD-SHELL $(escape_argument_list_continue "${HEALTHCHECK_CMD[@]}")"
	HEALTHCHECK_DATA+=("--health-cmd=$(json_array "${HEALTHCHECK_CMD[@]}")")
	add_run_argument "--health-cmd=$(json_array "${HEALTHCHECK_CMD[@]}")"

	if [[ $HEALTHCHECK_INTERVAL -gt 0 ]]; then
		# add_build_config "--healthcheck-interval=${HEALTHCHECK_INTERVAL}s"
		HEALTHCHECK_DATA+=("--health-interval=${HEALTHCHECK_INTERVAL}s")
		add_run_argument "--health-interval=${HEALTHCHECK_INTERVAL}s"
	fi
	if [[ $HEALTHCHECK_RETRY -gt 0 ]]; then
		# add_build_config "--healthcheck-retries=${HEALTHCHECK_RETRY}"
		HEALTHCHECK_DATA+=("--health-retries=${HEALTHCHECK_RETRY}")
		add_run_argument "--health-retries=${HEALTHCHECK_RETRY}"
	fi
	if [[ ${HEALTHCHECK_START_INTERVAL} -gt 0 ]]; then
		# add_build_config "--healthcheck-start-interval=${HEALTHCHECK_START_INTERVAL}"
		HEALTHCHECK_DATA+=("--health-startup-interval=${HEALTHCHECK_START_INTERVAL}s")
		add_run_argument "--health-startup-interval=${HEALTHCHECK_START_INTERVAL}s"
	fi
	if [[ ${HEALTHCHECK_START_PERIOD} -gt 0 ]]; then
		# add_build_config "--healthcheck-start-period=${HEALTHCHECK_START_PERIOD}"
		HEALTHCHECK_DATA+=("--health-start-period=${HEALTHCHECK_START_PERIOD}s")
		add_run_argument "--health-start-period=${HEALTHCHECK_START_PERIOD}s"
	fi
	if [[ ${HEALTHCHECK_TIMEOUT} -gt 0 ]]; then
		# add_build_config "--healthcheck-timeout=${HEALTHCHECK_TIMEOUT}"
		HEALTHCHECK_DATA+=("--health-timeout=${HEALTHCHECK_TIMEOUT}s")
		add_run_argument "--health-timeout=${HEALTHCHECK_TIMEOUT}s"
	fi

	add_build_config "--annotation=healthcheck=$(json_array "${HEALTHCHECK_DATA[@]}")"
}
register_argument_config __healthcheck_config

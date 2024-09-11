#!/usr/bin/env bash
declare -i HEALTHCHECK_RETRY
declare -a HEALTHCHECK_CMD

# healthcheck interval retry CMD...
function healthcheck() {
	HEALTHCHECK_INTERVAL="$1"
	HEALTHCHECK_RETRY="$2"
	shift
	shift
	HEALTHCHECK_CMD=("$@")
}

function healthcheck_timeout() {
	HEALTHCHECK_TIMEOUT="$1"
}

function healthcheck_start_period() {
	HEALTHCHECK_START_PERIOD="$1"
}

function __healthcheck_reset() {
	HEALTHCHECK_INTERVAL='5min'
	HEALTHCHECK_RETRY=3
	HEALTHCHECK_CMD=()
	HEALTHCHECK_START_PERIOD=''
	HEALTHCHECK_TIMEOUT=''
}
register_unit_reset __healthcheck_reset

function _healthcheck_config_buildah() {
	if [[ ${#HEALTHCHECK_CMD[@]} -eq 0 ]]; then
		return
	fi
	local IMAGE="$1"

	local I CMD=''

	for I in "${HEALTHCHECK_CMD[@]}"; do
		CMD+=" '${I}'"
	done

	_add_config "--healthcheck=CMD-SHELL ${CMD}"
	_add_config "--healthcheck-interval=${HEALTHCHECK_INTERVAL}"
	_add_config "--healthcheck-retries=${HEALTHCHECK_RETRY}"
	if [[ -n ${HEALTHCHECK_START_PERIOD} ]]; then
		_add_config "--healthcheck-start-period=${HEALTHCHECK_START_PERIOD}"
	fi
	if [[ -n ${HEALTHCHECK_TIMEOUT} ]]; then
		_add_config "--healthcheck-timeout=${HEALTHCHECK_TIMEOUT}"
	fi
	_healthcheck_reset
}

function _healthcheck_arguments_podman() {
	if [[ ${#HEALTHCHECK_CMD[@]} -eq 0 ]]; then
		return
	fi
	local I CMD=()

	for I in "${HEALTHCHECK_CMD[@]}"; do
		CMD+=("${I}")
	done

	_add_argument "--health-cmd=${CMD[*]}"

	_add_argument "--health-interval=${HEALTHCHECK_INTERVAL}"
	_add_argument "--health-retries=${HEALTHCHECK_RETRY}"
	if [[ -n ${HEALTHCHECK_START_PERIOD} ]]; then
		_add_argument "--health-start-period=${HEALTHCHECK_START_PERIOD}"
	fi
	if [[ -n ${HEALTHCHECK_TIMEOUT} ]]; then
		_add_argument "--health-timeout=${HEALTHCHECK_TIMEOUT}"
	fi
}

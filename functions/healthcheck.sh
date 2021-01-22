#!/usr/bin/env bash

HEALTHCHECK_INTERVAL='5min'
declare -i HEALTHCHECK_RETRY=3
declare -a HEALTHCHECK_CMD=()
HEALTHCHECK_START_PERIOD=''
HEALTHCHECK_TIMEOUT=''

# healthcheck interval retry CMD...
function healthcheck() {
	if command -v use_common_timer &>/dev/null; then
		use_common_timer containers-ensure-health
	fi
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

function _healthcheck_reset() {
	HEALTHCHECK_INTERVAL='5min'
	HEALTHCHECK_RETRY=3
	HEALTHCHECK_CMD=()
	HEALTHCHECK_START_PERIOD=''
	HEALTHCHECK_TIMEOUT=''
}

function _healthcheck_config_buildah() {
	if [[ ${#HEALTHCHECK_CMD[@]} -eq 0 ]]; then
		return
	fi
	local IMAGE="$1"

	local -a ARGS
	local I CMD=''

	for I in "${HEALTHCHECK_CMD[@]}"; do
		CMD+=" '${I}'"
	done

	ARGS+=("--healthcheck=CMD-SHELL $CMD")
	ARGS+=("--healthcheck-interval=$HEALTHCHECK_INTERVAL")
	ARGS+=("--healthcheck-retries=$HEALTHCHECK_RETRY")
	if [[ "$HEALTHCHECK_START_PERIOD" ]]; then
		ARGS+=("--healthcheck-start-period=$HEALTHCHECK_START_PERIOD")
	fi
	if [[ "$HEALTHCHECK_TIMEOUT" ]]; then
		ARGS+=("--healthcheck-timeout=$HEALTHCHECK_TIMEOUT")
	fi
	xbuildah config "${ARGS[@]}" "$IMAGE"
}

function _healthcheck_arguments_podman() {
	if [[ ${#HEALTHCHECK_CMD[@]} -eq 0 ]]; then
		return
	fi
	local I CMD=()

	for I in "${HEALTHCHECK_CMD[@]}"; do
		CMD+=("'${I}'")
	done

	_PODMAN_RUN_ARGS+=("--health-cmd=${CMD[*]}")

	_PODMAN_RUN_ARGS+=("--health-interval='$HEALTHCHECK_INTERVAL'")
	_PODMAN_RUN_ARGS+=("--health-retries='$HEALTHCHECK_RETRY'")
	if [[ "$HEALTHCHECK_START_PERIOD" ]]; then
		_PODMAN_RUN_ARGS+=("--health-start-period='$HEALTHCHECK_START_PERIOD'")
	fi
	if [[ "$HEALTHCHECK_TIMEOUT" ]]; then
		_PODMAN_RUN_ARGS+=("--health-timeout='$HEALTHCHECK_TIMEOUT'")
	fi
}

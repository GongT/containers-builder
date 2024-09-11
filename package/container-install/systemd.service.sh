#!/usr/bin/env bash

function unit_body() {
	local K="$1" V
	shift
	case "${K}" in
	ExecStop | ExecReload)
		# meanful config
		_S_BODY_CONFIG[${K}]=$(escape_argument_list_sameline "$@")
		;;
	RestartPreventExitStatus)
		# multiple directive, no escape
		_S_BODY_RAW_LINE+=("$K=$*")
		;;
	Environment*)
		# multiple directive, not command
		for V; do
			_S_BODY_RAW_LINE+=("$K=$(escape_argument "$V")")
		done
		;;
	ExecStartPre | ExecStartPost | ExecStopPre | ExecStopPost)
		# multiple directive, is command
		local COMMAND=$1 PREFIX=''
		shift
		split_exec_command_prefix "${COMMAND}"

		_S_BODY_RAW_LINE+=("${K}=${PREFIX}$(escape_argument_list_sameline "$COMMAND" "$@")")
		;;
	Exec*)
		die "can not set $K using unit_body()"
		;;
	*)
		_S_BODY_CONFIG[${K}]="${*}"
		;;
	esac
}

function systemd_slice_type() {
	local -i OOM_ADJUST=${2:-0}
	if [[ $1 == "entertainment" ]]; then
		_S_BODY_CONFIG[Slice]="services-entertainment.slice"
		_S_BODY_CONFIG[OOMPolicy]="stop"
		_S_BODY_CONFIG[OOMScoreAdjust]="$((OOM_ADJUST + 100))"
	elif [[ $1 == "idle" ]]; then
		_S_BODY_CONFIG[Slice]="services-idle.slice"
		_S_BODY_CONFIG[OOMPolicy]="kill"
		_S_BODY_CONFIG[OOMScoreAdjust]="$((OOM_ADJUST + 800))"
	elif [[ $1 == "infrastructure" ]]; then
		_S_BODY_CONFIG[Slice]="services-infrastructure.slice"
		_S_BODY_CONFIG[OOMPolicy]="continue"
		_S_BODY_CONFIG[OOMScoreAdjust]="$((OOM_ADJUST - 1000))"
	elif [[ $1 == "normal" ]]; then
		_S_BODY_CONFIG[Slice]="services-normal.slice"
		_S_BODY_CONFIG[OOMPolicy]=stop
		_S_BODY_CONFIG[OOMScoreAdjust]="${OOM_ADJUST}"
	else
		die "unknown systemd slice type: $1"
	fi
}

function __reset_body_config() {
	declare -ga _S_BODY_RAW_LINE=()
	declare -gA _S_BODY_CONFIG=()

	_S_BODY_CONFIG[WorkingDirectory]="/tmp"
	_S_BODY_CONFIG[RestartPreventExitStatus]="233"
	_S_BODY_CONFIG[Restart]="${DEFAULT_RESTART:-always}"
	_S_BODY_CONFIG[RestartSec]="1"
	_S_BODY_CONFIG[KillSignal]="SIGINT"
	_S_BODY_CONFIG[Slice]="services-normal.slice"
}
register_unit_reset __reset_body_config

function __unit_sanity() {
	if [[ -z ${_S_BODY_CONFIG['ExecStop']-} ]]; then
		local CONTAINER_STOP
		CONTAINER_STOP=$(install_script "${COMMON_LIB_ROOT}/staff/container-tools/container-manage-stop.sh")
		_S_BODY_CONFIG[ExecStop]=$(escape_argument_list_sameline "${CONTAINER_STOP}" "${PODMAN_TIMEOUT_TO_KILL}" "$(unit_get_scopename)")
	fi

}
register_unit_emit __unit_sanity

function _print_unit_service_section() {
	echo "# configs"
	for VAR_NAME in "${!_S_BODY_CONFIG[@]}"; do
		echo "${VAR_NAME}=${_S_BODY_CONFIG[${VAR_NAME}]}"
	done

	echo "# raw body lines"
	printf '%s\n' "${_S_BODY_RAW_LINE[@]}"
	echo "# end of raw"
}

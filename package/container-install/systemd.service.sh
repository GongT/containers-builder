#!/usr/bin/env bash

function unit_body() {
	local K="$1" V
	shift
	case "${K}" in
	ExecReload)
		# very special config
		custom_reload_command "$@"
		;;
	ExecStop)
		# very special config
		custom_stop_command "$@"
		;;
	RestartPreventExitStatus | AmbientCapabilities | CapabilityBoundingSet)
		# multiple directive, no escape
		if [[ -z ${_S_BODY_CONFIG["$K"]-} ]]; then
			_S_BODY_CONFIG["$K"]="$*"
		else
			_S_BODY_CONFIG["$K"]+=" $*"
		fi
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
		split_exec_command_prefix "${COMMAND}" PREFIX COMMAND

		if [[ ${K} == ExecStopPre ]]; then
			K=ExecStop
		fi

		_S_BODY_RAW_LINE+=("${K}=${PREFIX}$(escape_argument_list_sameline "$COMMAND" "$@")")
		;;
	Exec*)
		die "can not set $K using unit_body()"
		;;
	*)
		# meanful config
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

function __unit_gracefull_stopper() {
	local SCRIPT
	SCRIPT=$(install_script "${COMMON_LIB_ROOT}/staff/container-tools/manage-stop.sh")
	printf_command_direction ExecStop=- "${SCRIPT}"
}
function __unit_default_reloader() {
	local SCRIPT
	SCRIPT=$(install_script "${COMMON_LIB_ROOT}/staff/container-tools/manage-reload.sh")
	printf_command_direction ExecReload=- "${SCRIPT}"
}

function __unit_final_killer() {
	local SCRIPT
	SCRIPT=$(install_script "${COMMON_LIB_ROOT}/staff/container-tools/manage-kill.sh")
	printf_command_direction ExecStop=- "${SCRIPT}" stop
	printf_command_direction ExecStopPost=- "${SCRIPT}" kill
}

function _print_unit_service_section() {
	if [[ ${#CUSTOMSTOP_COMMAND[@]} -gt 0 ]]; then
		echo "# custom stop command"
		printf_command_direction ExecStop= "${CUSTOMSTOP_COMMAND[@]}"
	else
		echo "# default stop command"
		__unit_gracefull_stopper
	fi

	if [[ ${#CUSTOMRELOAD_COMMAND[@]} -gt 0 ]]; then
		printf_command_direction ExecReload= "${CUSTOMRELOAD_COMMAND[@]}"
	else
		echo "# default reload command"
		__unit_default_reloader
	fi

	echo "# configs"
	for VAR_NAME in "${!_S_BODY_CONFIG[@]}"; do
		echo "${VAR_NAME}=${_S_BODY_CONFIG[${VAR_NAME}]}"
	done

	echo "# raw body lines"
	printf '%s\n' "${_S_BODY_RAW_LINE[@]}"
	echo "# end of raw"

	__unit_final_killer
}

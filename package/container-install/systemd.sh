#!/usr/bin/env bash

_unit_reset() {
	declare -g _S_IMAGE=''
	declare -g _S_CURRENT_UNIT_SERVICE_TYPE=''
	declare -g _S_AT_=''
	declare -g _S_CURRENT_UNIT_TYPE=''
	declare -g _S_CURRENT_UNIT_NAME=''
	declare -g _S_CURRENT_UNIT_FILE=''
	declare -g _S_INSTALL=services.target

	declare -ga _S_COMMENTS=()

	declare -gA _S_UNIT_CONFIG=()
	if is_root; then
		_S_UNIT_CONFIG[Requires]+="services-pre.target"
		_S_UNIT_CONFIG[After]+="services-pre.target"
		_S_UNIT_CONFIG[RequiresMountsFor]+="${CONTAINERS_DATA_PATH}"
	fi
}

function _unit_init() {
	call_unit_reset
	_unit_reset
}

function auto_create_pod_service_unit() {
	create_pod_service_unit "${PROJECT_NAME}"
}
function create_pod_service_unit() {
	_arg_ensure_finish

	__create_unit__ pod "$1" service
}
function __create_unit__() {
	_unit_init
	_S_CURRENT_UNIT_SERVICE_TYPE="$1"
	_S_IMAGE="$2"
	_S_CURRENT_UNIT_TYPE="${3-service}"

	local NAME=$(basename "${_S_IMAGE}")

	if [[ ${NAME} == *@ ]]; then
		NAME="${NAME:0:-1}"
		_S_IMAGE="${_S_IMAGE:0:-1}"
		_S_AT_='@'
	fi

	_S_CURRENT_UNIT_NAME="${NAME}"

	set_script_root "${NAME}"

	_S_CURRENT_UNIT_FILE="$(_create_unit_name)"
	echo "creating unit file ${_S_CURRENT_UNIT_FILE}"
}

function _create_unit_name() {
	local IARG="${1-}"

	if [[ -n ${_S_CURRENT_UNIT_SERVICE_TYPE} ]]; then
		echo "${_S_CURRENT_UNIT_NAME}.${_S_CURRENT_UNIT_SERVICE_TYPE}${_S_AT_}${IARG}.${_S_CURRENT_UNIT_TYPE}"
	else
		echo "${_S_CURRENT_UNIT_NAME}${_S_AT_}${IARG}.${_S_CURRENT_UNIT_TYPE}"
	fi
}

function _create_service_lib() {
	local BODY
	BODY=$(
		_create_common_lib
		declare -p CURRENT_DIR PROJECT_NAME SCRIPTS_DIR

		printf "declare CONTAINER_ID=%q\n" "$(unit_get_scopename)"

		call_script_emit
	)
	write_file "${SCRIPTS_DIR}/service-library.sh" "$BODY"
}

function unit_write() {
	if [[ -z ${_S_CURRENT_UNIT_FILE} ]]; then
		die "create unit first."
	fi

	local TF
	TF=$(create_temp_file "${_S_CURRENT_UNIT_FILE}")
	_unit_assemble >"${TF}"
	if [[ -e "/usr/lib/systemd/system/${_S_CURRENT_UNIT_FILE}" ]]; then
		delete_file 0 "/usr/lib/systemd/system/${_S_CURRENT_UNIT_FILE}"
	fi

	install_common_system_support
	_create_service_lib

	if is_installing; then
		info_log "verify unit: ${TF}"
		printf "\e[38;5;9m%s\e[0m\n" "$(systemd-analyze verify "${TF}" 2>&1 | grep -F -- "$(basename "$TF")" || true)"
	fi
	copy_file --mode 0644 "${TF}" "${SYSTEM_UNITS_DIR}/${_S_CURRENT_UNIT_FILE}"
}

function unit_finish() {
	unit_write

	apply_systemd_service "${_S_CURRENT_UNIT_FILE}"

	_unit_init
}
function apply_systemd_service() {
	_arg_ensure_finish
	local UN="$1"

	if is_installing; then
		if [[ ${DISABLE_SYSTEMD_ENABLE:-no} != "yes" ]]; then
			if [[ -n ${_S_AT_} ]]; then
				if [[ -n ${SYSTEM_AUTO_ENABLE-} ]]; then
					local i='' N
					for i in "${SYSTEM_AUTO_ENABLE[@]}"; do
						N=$(_create_unit_name "${i}")
						add_service_to_enable "${N}"
					done
				fi
			else
				add_service_to_enable "${UN}"
			fi
		fi
	else
		if [[ -n ${_S_AT_} ]]; then
			local LIST I
			mapfile -t LIST < <(systemctl list-units --all --no-legend "${UN%.service}*.service" | sed 's/●//g' | awk '{print $1}')
			add_service_to_enable "${LIST[@]}"
		else
			add_service_to_enable "${UN}"
		fi
		info "systemd unit ${UN} disabled."
	fi
}

###
# get scoped name for use in systemd-unit file
# xxx.service -> xxx
# yyy@aaa.service -> yyy_aaa
###
function unit_get_scopename() {
	if [[ -z $_S_CURRENT_UNIT_FILE ]]; then
		print_failure "wrong call timing"
	fi
	local NAME="${_S_CURRENT_UNIT_NAME}"
	if [[ -n ${_S_AT_} ]]; then
		NAME="${NAME%@}"
		echo "${NAME}_%i"
	else
		echo "${NAME}"
	fi
}
function _export_base_envs() {
	printf 'declare -r UNIT_FILE_LOCATION=%q\n' "${SYSTEM_UNITS_DIR}/${_S_CURRENT_UNIT_FILE}"
	printf 'declare -r PODMAN_IMAGE_NAME=%q\n' "${_S_IMAGE}"
	echo "declare -r SERVICE_FILE='${_S_CURRENT_UNIT_FILE}'"
}
register_script_emit _export_base_envs

function _unit_assemble() {
	call_unit_emit

	local I
	echo "[Unit]"

	if [[ ${_S_INSTALL} == services.target ]]; then
		echo "DefaultDependencies=no"
	fi

	for VAR_NAME in "${!_S_UNIT_CONFIG[@]}"; do
		local CVAL="${_S_UNIT_CONFIG[${VAR_NAME}]}"
		if [[ ${CVAL} == " "* ]]; then
			CVAL=${CVAL:1}
		fi
		echo "${VAR_NAME}=${CVAL}"
	done

	local EXT="${_S_CURRENT_UNIT_TYPE}"
	local NAME="${_S_CURRENT_UNIT_NAME}"
	echo ""
	echo "[${EXT^}]
Type=notify
NotifyAccess=all"

	## exec start
	printf_command_direction ExecStart= "$(_service_executer_write)"

	## debug script
	local DEBUG_SCRIPT
	DEBUG_SCRIPT=$(_debugger_file_write)
	echo "# debug script: ${DEBUG_SCRIPT}"

	_print_unit_service_section

	echo "Environment=CONTAINER_ID=$(unit_get_scopename)"
	echo "Environment=UNIT_NAME=%n"
	echo "Environment=template_id=%i"
	echo "RuntimeDirectory=containers/services/$(unit_get_scopename)"

	if [[ -n ${_S_INSTALL} ]]; then
		echo ""
		echo "[Install]"
		echo "WantedBy=${_S_INSTALL}"
	fi

	echo ""
	echo "[X-Containers]"
	printf '%s\n' "${_S_COMMENTS[@]}"
	echo "MONO_ROOT_DIR=${MONO_ROOT_DIR-}"
	echo "CURRENT_DIR=${CURRENT_DIR}"
	echo "INSTALLER_SCRIPT=${CURRENT_FILE}"
	echo "PROJECT_NAME=${PROJECT_NAME}"
	echo "SCRIPTS_DIR=${SCRIPTS_DIR}"
}
function unit_depend() {
	if [[ -n $* ]]; then
		unit_unit After "$*"
		unit_unit Requires "$*"
	fi
}
function unit_unit() {
	local K=$1
	shift
	local V="$*"
	if echo "${K}" | grep -qE '^(Before|After|Requires|Wants|PartOf|WantedBy|RequiresMountsFor)$'; then
		_S_UNIT_CONFIG[${K}]+=" ${V}"
	elif echo "${K}" | grep -qE '^(WantedBy|RequiredBy)$'; then
		_S_INSTALL="${V}"
	else
		_S_UNIT_CONFIG[${K}]="${V}"
	fi
}
function unit_comment() {
	_S_COMMENTS+=("$*")
}

function unit_hook_start() {
	unit_body ExecStartPre "$@"
}
function unit_hook_poststart() {
	unit_body ExecStartPost "$@"
}
function unit_hook_prestop() {
	unit_body ExecStopPre "$@"
}
function unit_hook_stop() {
	unit_body ExecStopPost "$@"
}

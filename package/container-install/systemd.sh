#!/usr/bin/env bash

declare -a _S_PREP_FOLDER
declare -a _S_LINUX_CAP
declare -a _S_VOLUME_ARG
declare -A _S_UNIT_CONFIG
declare -A _S_BODY_CONFIG
declare -a _S_BODY_RAW_LINE
declare -a _S_PODMAN_ARGS
declare -a _S_COMMAND_LINE
declare -a _S_NETWORK_ARGS
declare -A _S_ENVIRONMENTS
declare -A _S_CONTROL_ENVS

_unit_reset() {
	_S_IMAGE=''
	_S_CURRENT_UNIT_SERVICE_TYPE=''
	_S_AT_=''
	_S_CURRENT_UNIT_TYPE=''
	_S_CURRENT_UNIT_NAME=''
	_S_CURRENT_UNIT_FILE=''
	_S_IMAGE_PULL="${DEFAULT_IMAGE_PULL:-always}"
	_S_HOST=''
	_S_KILL_TIMEOUT=5
	_S_KILL_FORCE=yes
	_S_INSTALL=services.target
	_S_START_WAIT=sleep:10
	_S_SYSTEMD=false

	_S_PREP_FOLDER=()
	_S_LINUX_CAP=()
	_S_VOLUME_ARG=()
	_S_PODMAN_ARGS=()
	_S_COMMAND_LINE=()
	_S_NETWORK_ARGS=()
	_S_ENVIRONMENTS=()
	_S_CONTROL_ENVS=()

	_S_EXEC_STOP=''
	_S_EXEC_STOP_RELOAD=''

	_S_UNIT_CONFIG=()
	if is_root; then
		_S_UNIT_CONFIG[Requires]+="services-pre.target"
		_S_UNIT_CONFIG[After]+="services-pre.target"
		_S_UNIT_CONFIG[RequiresMountsFor]+="${CONTAINERS_DATA_PATH}"
	fi

	_S_BODY_RAW_LINE=()
	_S_BODY_CONFIG=()
	_S_BODY_CONFIG[WorkingDirectory]="/tmp"
	_S_BODY_CONFIG[RestartPreventExitStatus]="233"
	_S_BODY_CONFIG[Restart]="${DEFAULT_RESTART:-always}"
	_S_BODY_CONFIG[RestartSec]="1"
	_S_BODY_CONFIG[KillSignal]="SIGINT"
	_S_BODY_CONFIG[Slice]="services-normal.slice"
}

function _unit_init() {
	_unit_reset

	## network.sh
	_network_reset

	## service env
	_S_CONTROL_ENVS[REGISTRY_AUTH_FILE]="/etc/containers/auth.json"

	## healthcheck.sh
	_healthcheck_reset

	## stop.sh
	_customstop_reset
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

function unit_write() {
	if [[ -z ${_S_CURRENT_UNIT_FILE} ]]; then
		die "create_xxxx_unit first."
	fi

	install_common_system_support

	local TF
	TF=$(create_temp_file "${_S_CURRENT_UNIT_FILE}")
	_unit_assemble >"${TF}"
	if [[ -e "/usr/lib/systemd/system/${_S_CURRENT_UNIT_FILE}" ]]; then
		delete_file 0 "/usr/lib/systemd/system/${_S_CURRENT_UNIT_FILE}"
	fi
	info_note "verify unit: ${TF}"
	printf "\e[38;5;9m%s\e[0m\n" "$(systemd-analyze verify "${TF}" 2>&1 | grep -F -- "$(basename "$TF")" || true)"
	copy_file "${TF}" "${SYSTEM_UNITS_DIR}/${_S_CURRENT_UNIT_FILE}"
}
_get_debugger_script() {
	echo "${SCRIPTS_DIR}/debug-startup.sh"
}
_debugger_file_write() {
	local I FILE_DATA
	local -a STARTUP_ARGS=()

	_create_startup_arguments
	FILE_DATA=$(
		echo "#!/usr/bin/env bash"
		echo "set -Eeuo pipefail"
		echo "declare -r CONTAINER_ID='$(_unit_get_scopename)'"
		echo "declare -r NAME='${_S_CURRENT_UNIT_NAME}'"
		echo "declare -r SERVICE_FILE='${_S_CURRENT_UNIT_FILE}'"
		export_base_envs
		find "${COMMON_LIB_ROOT}/staff/service-wait" -type f -not -name '99-*' -print0 \
			| sort -z \
			| while read -r -d '' F; do
				echo
				echo "##$(basename "$F")"
				tail -n +4 "$F"
				echo
			done

		declare -p _S_PREP_FOLDER

		echo "STARTUP_ARGC=${#_S_COMMAND_LINE[@]}"
		echo "declare -a STARTUP_ARGS=("
		printf '\t%q\n' "${STARTUP_ARGS[@]}"
		echo ")"

		cat "${COMMON_LIB_ROOT}/staff/debugger.sh"
	)
	write_file --mode 0755 "$(_get_debugger_script)" "${FILE_DATA}"
}

function unit_finish() {
	unit_write

	_debugger_file_write

	apply_systemd_service "${_S_CURRENT_UNIT_FILE}"

	_unit_init
}
function _systemctl_disable() {
	local UN=$1
	# if systemctl is-enabled -q "$UN"; then
	systemctl disable "${UN}" &>/dev/null || true
	systemctl reset-failed "${UN}" &>/dev/null || true
	# fi
}
function apply_systemd_service() {
	_arg_ensure_finish
	local UN="$1"

	if is_installing; then
		if [[ ${SYSTEMD_RELOAD:-yes} == yes ]]; then
			local AND_ENABLED=''
			systemctl daemon-reload
			info "systemd unit ${UN} created${AND_ENABLED}."
		fi

		if [[ ${DISABLE_SYSTEMD_ENABLE:-no} != "yes" ]]; then
			if [[ -n ${_S_AT_} ]]; then
				if [[ -n ${SYSTEM_AUTO_ENABLE-} ]]; then
					local i='' N
					for i in "${SYSTEM_AUTO_ENABLE[@]}"; do
						N=$(_create_unit_name "${i}")
						if ! systemctl is-enabled -q "${N}"; then
							systemctl enable "${N}"
						fi
					done
					AND_ENABLED=" and enabled ${SYSTEM_AUTO_ENABLE[*]}"
				fi
			else
				if ! systemctl is-enabled -q "${UN}"; then
					systemctl enable "${UN}"
					AND_ENABLED=' and enabled'
				fi
			fi
		fi
	else
		if [[ -n ${_S_AT_} ]]; then
			local LIST I
			mapfile -t LIST < <(systemctl list-units --all --no-legend "${UN%.service}*.service" | sed 's/●//g' | awk '{print $1}')
			for I in "${LIST[@]}"; do
				info_note "  disable ${I}..."
				_systemctl_disable "${I}"
			done
		else
			_systemctl_disable "${UN}"
		fi
		info "systemd unit ${UN} disabled."
	fi
}
function _unit_get_scopename() {
	local NAME="${_S_CURRENT_UNIT_NAME}"
	if [[ -n ${_S_AT_} ]]; then
		NAME="${NAME%@}"
		echo "${NAME}_%i"
	else
		echo "${NAME}"
	fi
}
function export_base_envs() {
	declare -r START_WAIT_DEFINE="${_S_START_WAIT}"
	declare -r NETWORK_TYPE="${_N_TYPE}"
	declare -r USING_SYSTEMD="${_S_SYSTEMD}"
	declare -r KILL_TIMEOUT="${_S_KILL_TIMEOUT}"
	declare -r KILL_IF_TIMEOUT="${_S_KILL_FORCE}"
	declare -p START_WAIT_DEFINE NETWORK_TYPE USING_SYSTEMD KILL_TIMEOUT KILL_IF_TIMEOUT
	declare -p PODMAN_QUADLET_DIR SYSTEM_UNITS_DIR PIDFILE_DIR
}
function _unit_assemble() {
	_set_network_if_not
	_commit_environment

	local PREP_FOLDERS_INS=()
	if [[ ${#_S_PREP_FOLDER[@]} -gt 0 ]]; then
		PREP_FOLDERS_INS+=("${_S_PREP_FOLDER[@]}")
	fi

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
	local SCOPE_ID="$(_unit_get_scopename)"
	echo ""
	echo "[${EXT^}]
Type=notify
NotifyAccess=all
# PIDFile=${PIDFILE_DIR}/${SCOPE_ID}.conmon.pid"

	if [[ ${_S_IMAGE_PULL} == "never" ]]; then
		:   # Nothing
	else # always
		local _PULL_HELPER
		_PULL_HELPER=$(install_script "${COMMON_LIB_ROOT}/staff/container-tools/pull-image.sh")
		printf_command_direction 'ExecStartPre=' "${_PULL_HELPER}" "${_S_IMAGE:-"${NAME}"}" "${_S_IMAGE_PULL}"
	fi

	local _SERVICE_WAITER="${SCRIPTS_DIR}/${_S_CURRENT_UNIT_NAME}.pod"
	local _WAITER_DATA _FILES _FILE
	_WAITER_DATA=$(
		echo '#!/usr/bin/env bash'
		echo 'set -Eeuo pipefail'
		export_base_envs
		declare -p PREP_FOLDERS_INS
		mapfile -t -d '' _FILES < <(find "${COMMON_LIB_ROOT}/staff/service-wait" -type f -print0 | sort -z)
		for _FILE in "${_FILES[@]}"; do
			echo
			echo "## $(basename "${_FILE}")"
			tail -n +4 "${_FILE}"
			echo
		done
	)
	write_file --mode 0755 "${_SERVICE_WAITER}" "${_WAITER_DATA}"

	echo "ExecStart=$(escape_argument "${_SERVICE_WAITER}") \\"

	local -a STARTUP_ARGS=(
		'--replace=true'
		"--conmon-pidfile=${PIDFILE_DIR}/${SCOPE_ID}.conmon.pid"
	)
	_create_startup_arguments

	escape_argument_list_continue "${STARTUP_ARGS[@]}"

	echo ""
	echo "# debug script: $(_get_debugger_script)"

	if [[ -z ${_S_BODY_CONFIG['ExecStop']-} ]]; then
		copy_file --mode 0755 "${COMMON_LIB_ROOT}/staff/container-tools/container-manage-stop.sh" "${SCRIPTS_DIR}/stop-container.sh"
		_CONTAINER_STOP=${SCRIPTS_DIR}/stop-container.sh
		printf_command_direction ExecStop= "${_CONTAINER_STOP}" "${_S_KILL_TIMEOUT}" "${SCOPE_ID}"
	fi

	for VAR_NAME in "${!_S_BODY_CONFIG[@]}"; do
		echo "${VAR_NAME}=${_S_BODY_CONFIG[${VAR_NAME}]}"
	done

	printf '%s\n' "${_S_BODY_RAW_LINE[@]}"

	echo "Environment=CONTAINER_ID=${SCOPE_ID}"
	echo "Environment=PODMAN_SYSTEMD_UNIT=%n"
	_commit_controller_environment

	if [[ -n ${_S_INSTALL} ]]; then
		echo ""
		echo "[Install]"
		echo "WantedBy=${_S_INSTALL}"
	fi

	echo ""
	echo "[X-Containers]"
	echo "IMAGE_NAME=${_S_IMAGE}"
	echo "IMAGE_NAME_PULL=${_S_IMAGE_PULL}"
	echo "CONTAINERS_DATA_PATH=${CONTAINERS_DATA_PATH}"
	echo "COMMON_LIB_ROOT=${COMMON_LIB_ROOT}"
	echo "MONO_ROOT_DIR=${MONO_ROOT_DIR-}"
	echo "CURRENT_DIR=${CURRENT_DIR}"
	echo "INSTALLER_SCRIPT=${CURRENT_FILE}"
	echo "PROJECT_NAME=${PROJECT_NAME}"
	echo "SYSTEM_COMMON_CACHE=${SYSTEM_COMMON_CACHE}"
	echo "SYSTEM_FAST_CACHE=${SYSTEM_FAST_CACHE}"
}

function _add_argument() {
	if ! is_set _PODMAN_RUN_ARGS; then
		die "wrong call timing"
	fi
	_PODMAN_RUN_ARGS+=("$@")
}

function _create_startup_arguments() {
	local -r SCOPE_ID="$(_unit_get_scopename)"
	STARTUP_ARGS+=("--hostname=${_S_HOST:-${SCOPE_ID}}")
	if [[ ${_S_SYSTEMD} == "true" ]]; then
		STARTUP_ARGS+=(--systemd=always --tty --tmpfs=/run)
	else
		STARTUP_ARGS+=(--systemd=false)
	fi
	local PODMANV
	PODMANV=$(podman info -f '{{.Version.Version}}')
	if [[ ${PODMANV} == "<no value>" ]]; then
		info_note "Using podman version 1."
		STARTUP_ARGS+=("--log-opt=path=/dev/null")
	else
		STARTUP_ARGS+=("--log-driver=none")
	fi

	STARTUP_ARGS+=("--restart=no")

	local _PODMAN_RUN_ARGS=() CAP_LIST

	_healthcheck_arguments_podman

	STARTUP_ARGS+=("${_PODMAN_RUN_ARGS[@]}")
	STARTUP_ARGS+=("${_S_NETWORK_ARGS[@]}" "${_S_PODMAN_ARGS[@]}" "${_S_VOLUME_ARG[@]}")
	if [[ ${#_S_LINUX_CAP[@]} -gt 0 ]]; then
		CAP_LIST=$(printf ",%s" "${_S_LINUX_CAP[@]}")
		STARTUP_ARGS+=("--cap-add=${CAP_LIST:1}")
	fi
	STARTUP_ARGS+=("--pull=never" "--rm" "${_S_IMAGE:-"${NAME}"}")
	STARTUP_ARGS+=("${_S_COMMAND_LINE[@]}")
}

function unit_data() {
	if [[ $1 == "safe" ]]; then
		_S_KILL_TIMEOUT=5
		_S_KILL_FORCE=yes
	elif [[ $1 == "danger" ]]; then
		_S_KILL_TIMEOUT=120
		_S_KILL_FORCE=no
	else
		die "unit_data <safe|danger>"
	fi
}
function unit_using_systemd() {
	_S_SYSTEMD=true
	# shellcheck disable=SC2016
	# unit_body ExecReload '/usr/bin/podman exec $CONTAINER_ID /usr/bin/bash /entrypoint/reload.sh'
}
function unit_depend() {
	if [[ -n $* ]]; then
		unit_unit After "$*"
		unit_unit Requires "$*"
		# unit_unit PartOf "$*"
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
	Environment)
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
		_S_BODY_CONFIG[${K}]="${V}"
		;;
	esac
}
function _unit_podman_network_arg() {
	_S_NETWORK_ARGS+=("$*")
}
function unit_podman_arguments() {
	local I
	if [[ -z $* ]]; then
		return
	fi
	for I; do
		_S_PODMAN_ARGS+=("${I}")
	done
}
function unit_podman_hostname() {
	_S_HOST=$1
	unit_body "Environment" "MY_HOSTNAME=${_S_HOST}"
}

function unit_podman_image_pull() {
	_S_IMAGE_PULL=$1
}
function unit_podman_image() {
	_S_IMAGE=$1
	shift
	_S_COMMAND_LINE=("$@")
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
function unit_start_notify() {
	local TYPE="$1" ARG="${2-}"
	_S_START_WAIT=
	case "${TYPE}" in
	socket)
		if [[ -n ${ARG} ]]; then
			die "touch method do not allow argument"
		fi
		_S_START_WAIT="sockets"
		;;
	port)
		if [[ ${ARG} != tcp:* ]] || [[ ${ARG} != udp:* ]]; then
			die "start notify port must use tcp:xxx or udp:xxx"
		fi
		_S_START_WAIT="net:${ARG}"
		;;
	sleep)
		_S_START_WAIT="sleep:${ARG}"
		;;
	output)
		_S_START_WAIT="output:${ARG}"
		;;
	touch)
		_S_START_WAIT="file"
		;;
	*)
		die "Unknown start notify method ${TYPE}, allow: socket, port, sleep, output, touch."
		;;
	esac
}

#!/usr/bin/env bash

declare -a _S_PREP_FOLDER
declare -a _S_LINUX_CAP
declare -a _S_VOLUME_ARG
declare -A _S_UNIT_CONFIG
declare -A _S_BODY_CONFIG
declare -a _S_EXEC_START_PRE
declare -a _S_EXEC_START_POST
declare -a _S_EXEC_STOP_PRE
declare -a _S_EXEC_STOP_POST
declare -a _S_PODMAN_ARGS
declare -a _S_COMMAND_LINE
declare -a _S_NETWORK_ARGS
declare -A _S_ENVIRONMENTS
declare -A _S_CONTROL_ENVS

declare -r SHARED_SOCKET_PATH=/dev/shm/container-shared-socksets

if podman stop --help 2>&1 | grep -q -- '--ignore'; then
	info_note "podman support --ignore flag"
	declare -r PODMAN_USE_IGNORE=yes
else
	echo "podman version is old. can't use --ignore flag" >&2
	declare -r PODMAN_USE_IGNORE=
fi

if podman run --help 2>&1 | grep -q -- '--replace'; then
	info_note "podman support --replace flag"
	declare -r PODMAN_USE_REPLACE=yes
else
	echo "podman version is old. can't use --replace flag" >&2
	declare -r PODMAN_USE_REPLACE=
fi

function _unit_init() {
	_S_IMAGE=
	_S_CURRENT_UNIT_SERVICE_TYPE=
	_S_AT_=
	_S_CURRENT_UNIT_TYPE=
	_S_CURRENT_UNIT_NAME=
	_S_CURRENT_UNIT_FILE=
	_S_IMAGE_PULL=${IMAGE_PULL:-always}
	_S_HOST=
	_S_STOP_CMD=
	_S_KILL_TIMEOUT=5
	_S_KILL_FORCE=yes
	_S_INSTALL=services.target
	_S_EXEC_RELOAD=
	_S_START_WAIT_SLEEP=10
	_S_START_WAIT_OUTPUT=
	_S_START_ACTIVE_FILE=
	_S_SYSTEMD=false

	_S_PREP_FOLDER=()
	_S_LINUX_CAP=()
	_S_VOLUME_ARG=()
	_S_UNIT_CONFIG=()
	_S_BODY_CONFIG=()
	_S_EXEC_START_PRE=()
	_S_EXEC_START_POST=()
	_S_EXEC_STOP_POST=()
	_S_EXEC_STOP_PRE=()
	_S_PODMAN_ARGS=()
	_S_COMMAND_LINE=()
	_S_NETWORK_ARGS=()
	_S_ENVIRONMENTS=()
	_S_CONTROL_ENVS=()

	_S_BODY_CONFIG[RestartPreventExitStatus]="233"
	_S_BODY_CONFIG[Restart]="always"
	_S_BODY_CONFIG[RestartSec]="10"
	_S_BODY_CONFIG[KillSignal]="SIGINT"
	_S_BODY_CONFIG[Slice]="services-normal.slice"

	## network.sh
	_N_TYPE=

	## service env
	_S_CONTROL_ENVS[REGISTRY_AUTH_FILE]="/etc/containers/auth.json"

	## healthcheck.sh
	_healthcheck_reset
}

function auto_create_pod_service_unit() {
	create_pod_service_unit "$PROJECT_NAME"
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

	local NAME=$(basename "$_S_IMAGE")

	if [[ $NAME == *@ ]]; then
		NAME="${NAME:0:-1}"
		_S_IMAGE="${_S_IMAGE:0:-1}"
		_S_AT_='@'
	fi

	_S_CURRENT_UNIT_NAME="$NAME"

	_S_CURRENT_UNIT_FILE="$(_create_unit_name)"
	echo "creating unit file $_S_CURRENT_UNIT_FILE"
}

function _create_unit_name() {
	local IARG="${1:-}"

	if [[ "$_S_CURRENT_UNIT_SERVICE_TYPE" ]]; then
		echo "$_S_CURRENT_UNIT_NAME.$_S_CURRENT_UNIT_SERVICE_TYPE$_S_AT_$IARG.$_S_CURRENT_UNIT_TYPE"
	else
		echo "$_S_CURRENT_UNIT_NAME$_S_AT_$IARG.$_S_CURRENT_UNIT_TYPE"
	fi
}

function unit_write() {
	if [[ -z $_S_CURRENT_UNIT_FILE ]]; then
		die "create_xxxx_unit first."
	fi

	install_common_system_support

	local -r TF=$(mktemp -u)
	_unit_assemble >$TF
	write_file "/usr/lib/systemd/system/$_S_CURRENT_UNIT_FILE" <$TF
	unlink $TF
}
_get_debugger_script() {
	echo "/usr/share/scripts/debug-startup-$(_unit_get_name).sh"
}
_debugger_file_write() {
	local -r TF=$(mktemp -u)
	local I
	local -a STARTUP_ARGS=()

	_create_startup_arguments
	{
		echo "#!/usr/bin/env bash"
		echo "set -Eeuo pipefail"
		echo "declare -r CONTAINER_ID='$(_unit_get_scopename)'"
		echo "declare -r NAME='$(_unit_get_name)'"
		echo "declare -r SERVICE_FILE='$_S_CURRENT_UNIT_FILE'"
		export_base_envs
		find "$COMMON_LIB_ROOT/tools/service-wait" -type f -not -name '99-*' -print0 \
			| sort -z \
			| xargs -0 -IF -n1 bash -c "echo && echo '##' \$(basename 'F') && tail -n +4 'F' && echo"
		declare -p _S_PREP_FOLDER

		echo "STARTUP_ARGC=${#_S_COMMAND_LINE[@]}"
		echo "declare -a STARTUP_ARGS=("
		for I in "${STARTUP_ARGS[@]}"; do
			echo -ne "\t"
			echo "${I}"
		done
		echo ")"

		cat "$COMMON_LIB_ROOT/staff/debugger.sh"
	} | write_executable_file "$(_get_debugger_script)"
}

function unit_finish() {
	unit_write

	_debugger_file_write

	apply_systemd_service "$_S_CURRENT_UNIT_FILE"

	_unit_init
}
function _systemctl_disable() {
	local UN=$1
	# if systemctl is-enabled -q "$UN"; then
	systemctl disable "$UN" &>/dev/null || true
	systemctl reset-failed "$UN" &>/dev/null || true
	# fi
}
function apply_systemd_service() {
	_arg_ensure_finish
	local UN="$1"

	if is_installing; then
		if [[ ${SYSTEMD_RELOAD:-yes} == yes ]]; then
			local AND_ENABLED=''
			systemctl daemon-reload
			info "systemd unit $UN created${AND_ENABLED}."
		fi

		if [[ ${DISABLE_SYSTEMD_ENABLE:-no} != "yes" ]]; then
			if [[ $_S_AT_ ]]; then
				if [[ "${SYSTEM_AUTO_ENABLE:-}" ]]; then
					local i='' N
					for i in "${SYSTEM_AUTO_ENABLE[@]}"; do
						N=$(_create_unit_name "$i")
						if ! systemctl is-enabled -q "$N"; then
							systemctl enable "$N"
						fi
					done
					AND_ENABLED=" and enabled ${SYSTEM_AUTO_ENABLE[*]}"
				fi
			else
				if ! systemctl is-enabled -q "$UN"; then
					systemctl enable "$UN"
					AND_ENABLED=' and enabled'
				fi
			fi
		fi
	else
		if [[ $_S_AT_ ]]; then
			local LIST I
			mapfile -t LIST < <(systemctl list-units --all --no-legend "${UN%.service}*.service" | sed 's/●//g' | awk '{print $1}')
			for I in "${LIST[@]}"; do
				info_note "  disable $I..."
				_systemctl_disable "$I"
			done
		else
			_systemctl_disable "$UN"
		fi
		info "systemd unit $UN disabled."
	fi
}
function _unit_get_extension() {
	echo "${_S_CURRENT_UNIT_TYPE}"
}
function _unit_get_name() {
	echo "${_S_CURRENT_UNIT_NAME}"
}
function _unit_get_scopename() {
	local NAME="$(_unit_get_name)"
	if [[ "$_S_AT_" ]]; then
		NAME="${NAME%@}"
		echo "${NAME}_%i"
	else
		echo "$NAME"
	fi
}
function export_base_envs() {
	(
		declare -r WAIT_TIME="$_S_START_WAIT_SLEEP"
		declare -r WAIT_OUTPUT="$_S_START_WAIT_OUTPUT"
		declare -r ACTIVE_FILE="$_S_START_ACTIVE_FILE"
		declare -r NETWORK_TYPE="$_N_TYPE"
		declare -r USING_SYSTEMD="$_S_SYSTEMD"
		declare -r KILL_TIMEOUT="$_S_KILL_TIMEOUT"
		declare -r KILL_IF_TIMEOUT="$_S_KILL_FORCE"
		declare -p WAIT_TIME WAIT_OUTPUT ACTIVE_FILE NETWORK_TYPE USING_SYSTEMD KILL_TIMEOUT KILL_IF_TIMEOUT
	)
}
function _unit_assemble() {
	_network_use_not_define
	_create_service_library
	_commit_environment

	local I
	echo "[Unit]"

	if [[ $_S_INSTALL == services.target ]]; then
		echo "DefaultDependencies=no"
	fi

	for VAR_NAME in "${!_S_UNIT_CONFIG[@]}"; do
		local CVAL="${_S_UNIT_CONFIG[$VAR_NAME]}"
		if [[ $CVAL == " "* ]]; then
			CVAL=${CVAL:1}
		fi
		echo "$VAR_NAME=${CVAL}"
	done

	local EXT="$(_unit_get_extension)"
	local NAME="$(_unit_get_name)"
	local SCOPE_ID="$(_unit_get_scopename)"
	echo ""
	echo "[${EXT^}]
Type=notify
NotifyAccess=all
PIDFile=/run/$SCOPE_ID.conmon.pid"

	if [[ ${_S_IMAGE_PULL} == "never" ]]; then
		:   # Nothing
	else # always
		local _PULL_HELPER
		_PULL_HELPER=$(install_script "$COMMON_LIB_ROOT/tools/pull-image.sh")
		echo "ExecStartPre=/usr/bin/env bash '$_PULL_HELPER' '${_S_IMAGE:-"$NAME"}' '${_S_IMAGE_PULL}'"
	fi

	if [[ ${#_S_EXEC_START_PRE[@]} -gt 0 ]]; then
		for I in "${_S_EXEC_START_PRE[@]}"; do
			echo "ExecStartPre=$I"
		done
		echo ''
	fi

	if [[ ${#_S_EXEC_START_POST[@]} -gt 0 ]]; then
		for I in "${_S_EXEC_START_POST[@]}"; do
			echo "ExecStartPost=$I"
		done
		echo ''
	fi

	echo "Environment=CONTAINER_ID=$SCOPE_ID"
	echo "Environment=PODMAN_SYSTEMD_UNIT=%n"
	_commit_controller_environment

	local PREP_FOLDERS_INS=()
	if [[ ${#_S_PREP_FOLDER[@]} -gt 0 ]]; then
		for I in "${_S_PREP_FOLDER[@]}"; do
			PREP_FOLDERS_INS+=("$I")
		done
	fi

	local _SERVICE_WAITER="/usr/share/scripts/$(_unit_get_name).pod"
	{
		echo '#!/usr/bin/env bash'
		echo 'set -Eeuo pipefail'
		export_base_envs
		declare -p PREP_FOLDERS_INS
		find "$COMMON_LIB_ROOT/tools/service-wait" -type f -print0 \
			| sort -z \
			| xargs -0 -IF -n1 bash -c "echo && echo '##' \$(basename 'F') && tail -n +4 'F' && echo"
	} | write_executable_file "$_SERVICE_WAITER"
	echo -n "ExecStart=${_SERVICE_WAITER} \\
	--conmon-pidfile=/run/$SCOPE_ID.conmon.pid '--name=$SCOPE_ID'"

	if [[ $PODMAN_USE_REPLACE == yes ]]; then
		echo -n " --replace=true"
	fi

	local -a STARTUP_ARGS=()
	_create_startup_arguments
	for I in "${STARTUP_ARGS[@]}"; do
		echo -ne " \\\\\n\t${I}"
	done
	echo ""
	echo "# debug script: $(_get_debugger_script)"

	for I in "${_S_EXEC_STOP_PRE[@]}"; do
		echo "ExecStopPre=$I"
	done
	if [[ -z $_S_STOP_CMD ]]; then
		echo "ExecStop=${_CONTAINER_STOP} $_S_KILL_TIMEOUT $SCOPE_ID"
		echo "TimeoutStopSec=$((_S_KILL_TIMEOUT + 10))"
	else
		echo "ExecStop=$_S_STOP_CMD"
	fi
	for I in "${_S_EXEC_STOP_POST[@]}"; do
		echo "ExecStopPost=$I"
	done

	if [[ -n $_S_EXEC_RELOAD ]]; then
		echo "ExecReload=$_S_EXEC_RELOAD"
	fi

	for VAR_NAME in "${!_S_BODY_CONFIG[@]}"; do
		echo "$VAR_NAME=${_S_BODY_CONFIG[$VAR_NAME]}"
	done

	echo ""
	echo "[Install]"
	echo "WantedBy=$_S_INSTALL"

	echo ""
	echo "[X-Containers]"
	echo "IMAGE_NAME=$_S_IMAGE"
	echo "IMAGE_NAME_PULL=$_S_IMAGE_PULL"
	echo "CONTAINERS_DATA_PATH=$CONTAINERS_DATA_PATH"
	echo "COMMON_LIB_ROOT=$COMMON_LIB_ROOT"
	echo "MONO_ROOT_DIR=$MONO_ROOT_DIR"
	echo "CURRENT_DIR=$CURRENT_DIR"
	echo "INSTALLER_SCRIPT=$CURRENT_FILE"
	echo "PROJECT_NAME=$PROJECT_NAME"
	echo "SYSTEM_COMMON_CACHE=$SYSTEM_COMMON_CACHE"
	echo "SYSTEM_FAST_CACHE=$SYSTEM_FAST_CACHE"
}

function _create_startup_arguments() {
	local -r SCOPE_ID="$(_unit_get_scopename)"
	STARTUP_ARGS+=("'--hostname=${_S_HOST:-$SCOPE_ID}'")
	if [[ $_S_SYSTEMD == "true" ]]; then
		STARTUP_ARGS+=(--systemd=always --tty)
	else
		STARTUP_ARGS+=(--systemd=false)
	fi
	local PODMANV=$(podman info -f '{{.Version.Version}}')
	if [[ $PODMANV == "<no value>" ]]; then
		info_note "Using $PODMAN version 1."
		STARTUP_ARGS+=("--log-opt=path=/dev/null")
	else
		STARTUP_ARGS+=("--log-driver=none")
	fi

	STARTUP_ARGS+=("--restart=no")

	local _PODMAN_RUN_ARGS=()
	_healthcheck_arguments_podman
	STARTUP_ARGS+=("${_PODMAN_RUN_ARGS[@]}")
	STARTUP_ARGS+=("${_S_NETWORK_ARGS[@]}" "${_S_PODMAN_ARGS[@]}" "${_S_VOLUME_ARG[@]}")
	if [[ ${#_S_LINUX_CAP[@]} -gt 0 ]]; then
		local CAP_ITEM CAP_LIST=""
		for CAP_ITEM in "${_S_LINUX_CAP[@]}"; do
			CAP_LIST+=",$CAP_ITEM"
		done
		STARTUP_ARGS+=("--cap-add=${CAP_LIST:1}")
	fi
	if [[ -n $_S_START_ACTIVE_FILE ]]; then
		STARTUP_ARGS+=("'--volume=ACTIVE_FILE:/tmp/ready-volume'" "'--env=ACTIVE_FILE=/tmp/ready-volume/$_S_START_ACTIVE_FILE'")
	fi
	STARTUP_ARGS+=("'--pull=never' --rm '${_S_IMAGE:-"$NAME"}'")
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
}
function unit_depend() {
	if [[ -n $* ]]; then
		unit_unit After "$*"
		unit_unit Requires "$*"
		unit_unit PartOf "$*"
	fi
}
function unit_unit() {
	local K=$1
	shift
	local V="$*"
	if echo "$K" | grep -qE '^(Before|After|Requires|Wants|PartOf|WantedBy)$'; then
		_S_UNIT_CONFIG[$K]+=" $V"
	elif echo "$K" | grep -qE '^(WantedBy)$'; then
		_S_INSTALL="$V"
	else
		_S_UNIT_CONFIG[$K]="$V"
	fi
}
function unit_body() {
	local K="$1"
	shift
	local V="$*"
	if echo "$K" | grep -qE '^(RestartPreventExitStatus|Environment)$'; then
		if [[ ${_S_BODY_CONFIG[$K]+found} == "found" ]]; then
			_S_BODY_CONFIG[$K]+=" "
		fi
		_S_BODY_CONFIG[$K]+="$V"
	elif echo "$K" | grep -qE '^(ExecStop)$'; then
		_S_STOP_CMD="$V"
	else
		_S_BODY_CONFIG[$K]="$V"
	fi
}
function _unit_podman_network_arg() {
	_S_NETWORK_ARGS+=("$*")
}
function unit_podman_arguments() {
	local I
	if ! [[ "$*" ]]; then
		return
	fi
	for I; do
		_S_PODMAN_ARGS+=("'$I'")
	done
}
function unit_podman_hostname() {
	_S_HOST=$1
	unit_body "Environment" "MY_HOSTNAME=$_S_HOST"
}

function unit_podman_image_pull() {
	_S_IMAGE_PULL=$1
}
function unit_podman_image() {
	_S_IMAGE=$1
	shift
	_S_COMMAND_LINE=("$@")
}
function unit_hook_poststart() {
	_S_EXEC_START_POST+=("$*")
}
function unit_hook_start() {
	_S_EXEC_START_PRE+=("$*")
}
function unit_hook_prestop() {
	_S_EXEC_STOP_PRE+=("$*")
}
function unit_hook_stop() {
	_S_EXEC_STOP_POST+=("$*")
}
function unit_reload_command() {
	_S_EXEC_RELOAD="$*"
}
function unit_start_notify() {
	local TYPE="$1" ARG="${2-}"
	_S_START_WAIT_SLEEP=
	_S_START_WAIT_OUTPUT=
	_S_START_ACTIVE_FILE=
	case "$TYPE" in
	sleep)
		_S_START_WAIT_SLEEP="$ARG"
		;;
	output)
		_S_START_WAIT_OUTPUT="$ARG"
		;;
	touch)
		if [[ -z $ARG ]]; then
			ARG="$_S_CURRENT_UNIT_FILE.$RANDOM.ready"
		fi
		_S_START_ACTIVE_FILE="$ARG"
		;;
	*)
		die "Unknown start notify method $TYPE, allow: sleep, output, touch."
		;;
	esac
}
function _create_service_library() {
	if [[ ${_CONTAINER_STOP+found} == "found" ]]; then
		return
	fi
	mkdir -p /usr/share/scripts/

	cat "$COMMON_LIB_ROOT/tools/stop-container.sh" | write_executable_file_share /usr/share/scripts/stop-container.sh
	_CONTAINER_STOP=/usr/share/scripts/stop-container.sh

	cat "$COMMON_LIB_ROOT/tools/lowlevel-clear.sh" | write_executable_file_share /usr/share/scripts/lowlevel-clear.sh
	_LOWLEVEL_CLEAR=/usr/share/scripts/lowlevel-clear.sh

	cat "$COMMON_LIB_ROOT/tools/update-hosts.sh" | write_executable_file_share /usr/share/scripts/update-hosts.sh
	_UPDATE_HOSTS=/usr/share/scripts/update-hosts.sh
}

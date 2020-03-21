declare -a _S_PREP_FOLDER
declare -a _S_VOLUME_ARG
declare -A _S_UNIT_CONFIG
declare -A _S_BODY_CONFIG
declare -a _S_EXEC_START_PRE
declare -a _S_EXEC_STOP_POST
declare -a _S_PODMAN_ARGS
declare -a _S_COMMAND_LINE
declare -a _S_NETWORK_ARGS

function _unit_init() {
	_S_IMAGE=
	_S_IMAGE_PULL=never
	_S_HOST=
	_S_STOP_CMD=
	_S_KILL_TIMEOUT=5
	_S_KILL_FORCE=yes
	_S_INSTALL=multi-user.target
	_S_EXEC_RELOAD=
	_S_START_WAIT_SLEEP=10
	_S_START_WAIT_OUTPUT=
	_S_START_ACTIVE_FILE=

	_S_CURRENT_UNIT=
	_S_PREP_FOLDER=()
	_S_VOLUME_ARG=()
	_S_UNIT_CONFIG=()
	_S_BODY_CONFIG=()
	_S_EXEC_START_PRE=()
	_S_EXEC_STOP_POST=()
	_S_PODMAN_ARGS=()
	_S_COMMAND_LINE=()
	_S_NETWORK_ARGS=()
	# _S_BODY_CONFIG[RestartPreventExitStatus]="125 126 127"
	_S_BODY_CONFIG[Restart]="no"
	_S_BODY_CONFIG[RestartSec]="10"
	_S_BODY_CONFIG[KillSignal]="SIGINT"
	_S_BODY_CONFIG[TimeoutStopSec]="10"
	_S_REQUIRE_INFRA=

	## network.sh
	_N_TYPE=
}

function create_unit() {
	_unit_init
	_S_IMAGE="$1"
	local NAME=$(basename "$1")
	_S_CURRENT_UNIT="$NAME.${2-service}"
	echo "creating unit file $NAME.${2-service}"
}

function unit_write() {
	if [[ -z "$_S_CURRENT_UNIT" ]]; then
		die "create_unit first."
	fi
	_unit_assemble | write_file "/usr/lib/systemd/system/$_S_CURRENT_UNIT"
}
function unit_finish() {
	unit_write
	local UN="$_S_CURRENT_UNIT"
	_unit_init

	if is_installing; then
		if [[ "${SYSTEMD_RELOAD-yes}" == "yes" ]]; then
			info systemctl daemon-reload
			systemctl daemon-reload
		fi
		if ! systemctl is-enabled -q "$UN"; then
			info systemctl enable "$UN"
			systemctl enable "$UN"
		fi
		info "systemd unit $UN create and enabled."
	else
		if systemctl is-enabled -q "$UN"; then
			info systemctl disable "$UN"
			systemctl disable "$UN"
		fi
		info "systemd unit $UN disabled."
	fi
}
function _unit_assemble() {
	_network_use_not_define

	local I
	echo "[Unit]"

	if [[ "${#_S_PREP_FOLDER[@]}" -gt 0 ]]; then
		unit_depend wait-mount.service
	fi

	for VAR_NAME in "${!_S_UNIT_CONFIG[@]}"; do
		echo "$VAR_NAME=${_S_UNIT_CONFIG[$VAR_NAME]}"
	done

	local EXT="${_S_CURRENT_UNIT##*.}"
	local NAME="${_S_CURRENT_UNIT%%.*}"
	if [[ "$NAME" = *"@" ]]; then
		NAME="${NAME%@}"
		local SCOPE_ID="${NAME}_%I"
	else
		local SCOPE_ID="$NAME"
	fi
	echo ""
	echo "[${EXT^}]
Type=forking
NotifyAccess=none
PIDFile=/run/$SCOPE_ID.conmon.pid"

	if [[ "${#_S_PREP_FOLDER[@]}" -gt 0 ]]; then
		echo -n "ExecStartPre=/usr/bin/mkdir -p"
		for I in "${_S_PREP_FOLDER[@]}"; do
			echo -n " '$I'"
		done
		echo ''
	fi

	if [[ -z "$_S_STOP_CMD" ]]; then
		echo "ExecStartPre=-/usr/bin/podman stop -t $_S_KILL_TIMEOUT $SCOPE_ID"
	else
		echo "ExecStartPre=-$_S_STOP_CMD"
	fi
	if [[ "$_S_KILL_FORCE" == "yes" ]]; then
		echo "ExecStartPre=-/usr/bin/podman rm --force $SCOPE_ID"
	fi
	if [[ "$_S_KILL_FORCE" == "yes" ]]; then
		echo "ExecStopPost=-/usr/bin/podman rm --force $SCOPE_ID"
	fi

	if [[ "${#_S_EXEC_START_PRE[@]}" -gt 0 ]]; then
		for I in "${_S_EXEC_START_PRE[@]}"; do
			echo -n "ExecStartPre=$I"
		done
		echo ''
	fi

	if [[ "${_SERVICE_WAITER+found}" != "found" ]]; then
		_create_service_library
	fi

	echo "Environment=CONTAINER_ID=$SCOPE_ID"
	echo "Environment='WAIT_TIME=$_S_START_WAIT_SLEEP'"
	echo "Environment='WAIT_OUTPUT=$_S_START_WAIT_OUTPUT'"
	echo "Environment='ACTIVE_FILE=$_S_START_ACTIVE_FILE'"
	echo "ExecStart=${_SERVICE_WAITER} run \\
	--detach-keys=q \\
	--conmon-pidfile=/run/$SCOPE_ID.conmon.pid \\
	--hostname=${_S_HOST:-$SCOPE_ID} --name=$SCOPE_ID \\
	--systemd=false --log-opt=path=/dev/null --restart=no \\"
	for I in "${_S_NETWORK_ARGS[@]}"; do
		echo -e "\t$I \\"
	done
	for I in "${_S_PODMAN_ARGS[@]}"; do
		echo -e "\t$I \\"
	done
	for I in "${_S_VOLUME_ARG[@]}"; do
		echo -e "\t$I \\"
	done
	if [[ -n "$_S_START_ACTIVE_FILE" ]] ; then
		echo -e "\t--volume=ACTIVE_FILE:/tmp/ready-volume \\"
		echo -e "\t'--env=ACTIVE_FILE=/tmp/ready-volume/$_S_START_ACTIVE_FILE' \\"
	fi
	echo -ne "\t--pull=${_S_IMAGE_PULL-never} --rm ${_S_IMAGE:-"$NAME"}"
	for I in "${_S_COMMAND_LINE[@]}"; do
		echo -n " '$I'"
	done
	echo ""

	if [[ -z "$_S_STOP_CMD" ]]; then
		echo "ExecStop=/usr/bin/podman stop -t $_S_KILL_TIMEOUT $SCOPE_ID"
	else
		echo "ExecStop=$_S_STOP_CMD"
	fi
	for I in "${_S_EXEC_STOP_POST[@]}"; do
		echo "ExecStopPost=$I"
	done

	if [[ -n "$_S_EXEC_RELOAD" ]]; then
		echo "ExecReload=$_S_EXEC_RELOAD"
	fi

	for VAR_NAME in "${!_S_BODY_CONFIG[@]}"; do
		echo "$VAR_NAME=${_S_BODY_CONFIG[$VAR_NAME]}"
	done

	echo ""
	echo "[Install]"
	echo "WantedBy=$_S_INSTALL"
}

declare -r BIND_RBIND="noexec,nodev,nosuid,rw,rbind"

function unit_data() {
	if [[ "$1" == "safe" ]]; then
		_S_KILL_TIMEOUT=5
		_S_KILL_FORCE=yes
	elif [[ "$1" == "danger" ]]; then
		_S_KILL_TIMEOUT=120
		_S_KILL_FORCE=no
	else
		die "unit_data <safe|danger>"
	fi
}

function unit_fs_tempfs() {
	local SIZE="$1" PATH="$2"
	_S_VOLUME_ARG+=("'--mount=type=tmpfs,tmpfs-size=$SIZE,destination=$PATH'")
}
function unit_fs_bind() {
	local FROM="$1" TO="$2" OPTIONS=":noexec,nodev,nosuid"
	if [[ "${3+'set'}" == 'set' ]]; then
		RO=":$3"
	fi
	if [[ "${FROM:0:1}" != "/" ]]; then
		FROM="$CONTAINERS_DATA_PATH/$FROM"
	fi

	_S_PREP_FOLDER+=("$FROM")
	_S_VOLUME_ARG+=("'--volume=$FROM:$TO$OPTIONS'")
}

function unit_depend() {
	if [[ -n "$*" ]]; then
		unit_unit After "$*"
		unit_unit Requires "$*"

		if echo "$*" | grep -q -- "virtual-gateway.service"; then
			_S_REQUIRE_INFRA=yes
		fi
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
	if echo "$K" | grep -qE '^(RestartPreventExitStatus)$'; then
		_S_BODY_CONFIG[$K]+=" $V"
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
	_S_PODMAN_ARGS+=("$@")
}
function unit_podman_hostname() {
	_S_HOST=$1
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
	_S_EXEC_START_PRE+=("$*")
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
		if [[ -z "$ARG" ]]; then
			ARG="$_S_CURRENT_UNIT.$RANDOM.ready"
		fi
		_S_START_ACTIVE_FILE="$ARG"
	;;
	*)
		die "Unknown start notify method $TYPE, allow: sleep, output, touch."
	;;
	esac
}
function _create_service_library() {
	mkdir -p /usr/share/scripts/

	cat "$COMMON_LIB_ROOT/tools/service-wait.sh" >/usr/share/scripts/service-wait.sh
	chmod a+x /usr/share/scripts/service-wait.sh
	_SERVICE_WAITER=/usr/share/scripts/service-wait.sh

	cat "$COMMON_LIB_ROOT/tools/lowlevel-clear.sh" >/usr/share/scripts/lowlevel-clear.sh
	chmod a+x /usr/share/scripts/lowlevel-clear.sh
	_LOWLEVEL_CLEAR=/usr/share/scripts/lowlevel-clear.sh
}

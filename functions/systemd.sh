declare -a _S_PREP_FOLDER
declare -a _S_VOLUME_ARG
declare -A _S_UNIT_CONFIG
declare -A _S_BODY_CONFIG
declare -a _S_EXEC_START_PRE
declare -a _S_EXEC_STOP_POST
declare -a _S_PODMAN_ARGS
declare -a _S_COMMAND_LINE

function _unit_init() {
	_S_IMAGE=
	_S_HOST=
	_S_STOP_CMD=
	_S_KILL_TIMEOUT=5
	_S_KILL_FORCE=yes
	_S_INSTALL=machines.target
	_S_NETWORK=
	_S_EXEC_RELOAD=

	_S_CURRENT_UNIT=
	_S_PREP_FOLDER=()
	_S_VOLUME_ARG=()
	_S_UNIT_CONFIG=()
	_S_BODY_CONFIG=()
	_S_EXEC_START_PRE=()
	_S_EXEC_STOP_POST=()
	_S_PODMAN_ARGS=()
	_S_COMMAND_LINE=()
	_S_BODY_CONFIG[RestartPreventExitStatus]="125 126 127"
	_S_BODY_CONFIG[Restart]="always"
	_S_BODY_CONFIG[RestartSec]="10"
	_S_REQUIRE_INFRA=
}

function create_unit() {
	_unit_init
	_S_CURRENT_UNIT="$1.${2-service}"
	echo "creating unit file $1.${2-service}"
}

function unit_finish() {
	local UN="$_S_CURRENT_UNIT"
	if [[ -z "$UN" ]]; then
		die "create_unit first."
	fi
	_unit_assemble | write_file "/usr/lib/systemd/system/$UN"

	if is_installing ; then
		if [[ "${SYSTEMD_RELOAD-yes}" == "yes" ]]; then
			systemctl daemon-reload
		fi
		info systemctl enable "$UN"
		systemctl enable "$UN"
		info "systemd unit $UN create and enabled."
	else
		info systemctl disable "$UN"
		systemctl disable "$UN"
		info "systemd unit $UN disabled."
	fi
}
function _unit_assemble() {
	local I
	echo "[Unit]"

	if [[ "${#_S_PREP_FOLDER[@]}" -gt 0 ]] && ! [[ "$_S_REQUIRE_INFRA" == "yes" ]]; then
		unit_depend wait-mount.service
	fi

	for VAR_NAME in "${!_S_UNIT_CONFIG[@]}"; do
		echo "$VAR_NAME=${_S_UNIT_CONFIG[$VAR_NAME]}"
	done

	local EXT="${_S_CURRENT_UNIT##*.}"
	local NAME="${_S_CURRENT_UNIT%%.*}"
	echo ""
	echo "[${EXT^}]
Type=simple
PIDFile=/run/$NAME.pid"
	if [[ -z "$_S_STOP_CMD" ]]; then
		echo "ExecStartPre=-/usr/bin/podman stop -t $_S_KILL_TIMEOUT $NAME"
	else
		echo "ExecStartPre=-$_S_STOP_CMD"
	fi
	if [[ "$_S_KILL_FORCE" == "yes" ]]; then
		echo "ExecStartPre=-/usr/bin/podman rm --ignore --force $NAME"
	fi

	if [[ "${#_S_EXEC_START_PRE[@]}" -gt 0 ]]; then
		for I in "${_S_EXEC_START_PRE[@]}"; do
			echo -n "ExecStartPre=$I"
		done
		echo ''
	fi

	if [[ "${#_S_PREP_FOLDER[@]}" -gt 0 ]]; then
		echo -n "ExecStartPre=/usr/bin/mkdir -p"
		for I in "${_S_PREP_FOLDER[@]}"; do
			echo -n " '$I'"
		done
		echo ''
	fi

	echo "ExecStart=/usr/bin/podman run \\
	--conmon-pidfile=/run/$NAME.conmon.pid \\
	--hostname=${_S_HOST:-$NAME} --name=$NAME \\
	--systemd=false --log-opt=path=/dev/null \\"
	if [[ -n "$_S_NETWORK" ]]; then
		echo "${_S_NETWORK} \\"
	fi
	for I in "${_S_PODMAN_ARGS[@]}"; do
		echo -e "\t$I \\"
	done
	for I in "${_S_VOLUME_ARG[@]}"; do
		echo -e "\t$I \\"
	done
	echo -ne "\t--pull=never --rm ${_S_IMAGE:-"gongt/$NAME"}"
	for I in "${_S_COMMAND_LINE[@]}"; do
		echo -n " '$I'"
	done
	echo ""

	if [[ -z "$_S_STOP_CMD" ]]; then
		echo "ExecStop=/usr/bin/podman stop -t $_S_KILL_TIMEOUT $NAME"
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

	_unit_init
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
	if echo "$K" | grep -qE '^(Before|After|Requires|Wants)$'; then
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
	_S_NETWORK="$*"
}
function unit_podman_network_publish() {
	_S_NETWORK="$NETWORK_TYPE"
	unit_depend $INFRA_DEP
}
function unit_podman_arguments() {
	_S_PODMAN_ARGS=("$@")
}
function unit_podman_hostname() {
	_S_HOST=$1
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

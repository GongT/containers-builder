declare -r BIND_RBIND="noexec,nodev,nosuid,rw,rbind"

function unit_fs_tempfs() {
	local SIZE="$1" PATH="$2"
	_S_VOLUME_ARG+=("--mount=type=tmpfs,tmpfs-size=${SIZE},destination=${PATH}")
}
function unit_volume() {
	local NAME="$1" TO="$2" OPTIONS=":noexec,nodev,nosuid"
	if [[ $# -gt 2 ]]; then
		OPTIONS+=",$3"
	fi

	_S_PREP_FOLDER+=("${NAME}")
	_S_VOLUME_ARG+=("--volume=${NAME}:${TO}${OPTIONS}")
}
function unit_fs_bind() {
	local FROM="$1" TO="$2" OPTIONS=":noexec,nodev,nosuid,rslave"
	if [[ $# -gt 2 ]]; then
		OPTIONS+=",$3"
	fi
	if [[ ${FROM:0:1} != "/" ]]; then
		FROM="${CONTAINERS_DATA_PATH}/${FROM}"
	fi

	_S_PREP_FOLDER+=("${FROM}")
	_S_VOLUME_ARG+=("--volume=${FROM}:${TO}${OPTIONS}")
}
function _pass_socket_path_env() {
	environment_variable "SHARED_SOCKET_PATH=/run/sockets"
}
function shared_sockets_use() {
	_pass_socket_path_env
	if ! echo "${_S_VOLUME_ARG[*]}" | grep "${SHARED_SOCKET_PATH}"; then
		unit_fs_bind "${SHARED_SOCKET_PATH}" /run/sockets
	fi
}
function shared_sockets_provide() {
	_pass_socket_path_env
	if ! echo "${_S_VOLUME_ARG[*]}" | grep "${SHARED_SOCKET_PATH}"; then
		unit_fs_bind "${SHARED_SOCKET_PATH}" /run/sockets
	fi
	local -a FULLPATH=() ARGS=()
	local i
	for i; do
		if ! [[ $i == *.sock || $i == *.socket ]]; then
			i+='.sock'
		fi
		ARGS+=("$i")
		FULLPATH+=("${SHARED_SOCKET_PATH}/${i}")
		_S_PROVIDE_SOCKETS+=("$i")
	done
}

function __reset_volumes() {
	declare -ga _S_PREP_FOLDER=()
	declare -ga _S_PROVIDE_SOCKETS=()
	declare -ga _S_VOLUME_ARG=()
}
register_unit_reset __reset_volumes

function __pass_volume_arguments() {
	add_run_argument "${_S_VOLUME_ARG[@]}"
}
register_argument_config __pass_volume_arguments

function __export_volumes() {
	local PREPARE_FOLDERS=()
	if [[ ${#_S_PREP_FOLDER[@]} -gt 0 ]]; then
		PREPARE_FOLDERS+=("${_S_PREP_FOLDER[@]}")
	fi
	local -ra PROVIDED_SOCKETS=("${_S_PROVIDE_SOCKETS[@]}")
	declare -p PROVIDED_SOCKETS

	local -r PREPARE_FOLDERS
	printf "declare -xr SHARED_SOCKET_PATH=%q\n" "${SHARED_SOCKET_PATH}"
	declare -p PREPARE_FOLDERS
}
register_script_emit __export_volumes

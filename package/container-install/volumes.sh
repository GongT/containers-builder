declare -r BIND_RBIND="noexec,nodev,nosuid,rw,rbind"

function unit_fs_tempfs() {
	local SIZE="$1" PATH="$2"
	_S_VOLUME_ARG+=("'--mount=type=tmpfs,tmpfs-size=${SIZE},destination=${PATH}'")
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
	controller_environment_variable "SHARED_SOCKET_PATH=${SHARED_SOCKET_PATH}"
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
	local -a FULLPATH=()
	for i; do
		FULLPATH+=("'${SHARED_SOCKET_PATH}/${i}.sock'")
	done
	__provide_sockets_for_wait "$@"

	unit_hook_start "/usr/bin/rm -f ${FULLPATH[*]}"
	unit_hook_stop "/usr/bin/rm -f ${FULLPATH[*]}"
}

function __reset_volumes() {
	declare -a _S_PREP_FOLDER=()
}
register_unit_reset __reset_volumes

function __export_volumes() {
	local PREPARE_FOLDERS=()
	if [[ ${#_S_PREP_FOLDER[@]} -gt 0 ]]; then
		PREPARE_FOLDERS+=("${_S_PREP_FOLDER[@]}")
	fi
	local -r PREPARE_FOLDERS
	declare -p PREPARE_FOLDERS
}
register_script_emit __export_volumes

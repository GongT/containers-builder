function install_script() {
	local FILE_PATH=$1 NAME=${2-}

	FILE_PATH=$(realpath -e "$FILE_PATH")
	if [[ ! -f ${FILE_PATH} ]]; then
		die "Cannot found script file: ${FILE_PATH}"
	fi

	if [[ -z ${NAME} ]]; then
		NAME="$(basename "$1" .sh)"
	fi

	local OUTPUT="${SCRIPTS_DIR}/${NAME}"
	install_modified_script "${FILE_PATH}" "${OUTPUT}"

	echo "${OUTPUT}"
}
function install_common_script() {
	local FILE_PATH=$1 NAME=${2-}
	FILE_PATH=$(realpath -e "$FILE_PATH")
	if [[ ! -f ${FILE_PATH} ]]; then
		die "Cannot found script file: ${FILE_PATH}"
	fi

	if [[ -z ${NAME} ]]; then
		NAME="$(basename "$1" .sh)"
	fi

	local OUTPUT="${SHARED_SCRIPTS_DIR}/${NAME}"
	install_modified_script "${FILE_PATH}" "${OUTPUT}"

	echo "${OUTPUT}"
}
function install_binary() {
	local FILE=$1 NAME="${2-}"
	if [[ -z ${NAME} ]]; then
		NAME="$(basename "$1" .sh)"
	fi

	local _SRC="${SCRIPTS_DIR}/${NAME}"
	install_modified_script "${FILE}" "${_SRC}"

	local AS="${BINARY_DIR}/${NAME}"
	write_file --nodir --mode 0755 "${AS}" "$(head -n1 "${_SRC}")
source '${_SRC}'"
	info "installed binary: \e[38;5;2m${AS}"
}
function install_global_binary() {
	local FILE=$1 NAME="${2-}"
	if [[ -z ${NAME} ]]; then
		NAME="$(basename "$1" .sh)"
	fi

	local _SRC="${SHARED_SCRIPTS_DIR}/${NAME}"
	install_modified_script "${FILE}" "${_SRC}"

	local AS="${BINARY_DIR}/${NAME}"
	write_file --nodir --mode 0755 "${AS}" "$(head -n1 "${_SRC}")
source '${_SRC}'"
	info "installed binary: \e[38;5;2m${AS}"
}

function install_modified_script() {
	local SRC=$1 TARGET=$2 DATA

	local SOURCE_STMT='source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/service-library.sh"'
	SOURCE_STMT+=$(printf "; declare WHO_AM_I=%q" "${WHO_AM_I-"${SRC}"}")
	unset WHO_AM_I

	DATA=$(sed -E 's#source ".+/include.sh"#___replace___me___#g' "${SRC}")
	DATA=${DATA//___replace___me___/$SOURCE_STMT}

	write_file --mode 0755 "${TARGET}" "${DATA}"
}

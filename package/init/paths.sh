if [[ ${CONTAINERS_DATA_PATH+found} != "found" ]]; then
	CONTAINERS_DATA_PATH="/data/AppData"
fi
declare -xr CONTAINERS_DATA_PATH

if [[ ${SYSTEM_COMMON_CACHE+found} != "found" ]]; then
	if is_root; then
		SYSTEM_COMMON_CACHE='/var/cache'
	else
		SYSTEM_COMMON_CACHE="${HOME}/.cache"
	fi
fi
if [[ ${SYSTEM_FAST_CACHE+found} != "found" ]]; then
	SYSTEM_FAST_CACHE="${SYSTEM_COMMON_CACHE}"
fi
declare -xr SYSTEM_COMMON_CACHE SYSTEM_FAST_CACHE
declare -xr PRIVATE_CACHE="${SYSTEM_COMMON_CACHE}/image-build"
mkdir -p "${PRIVATE_CACHE}"

if [[ ${REGISTRY_AUTH_FILE+found} != "found" ]]; then
	declare -xr REGISTRY_AUTH_FILE="/etc/containers/auth.json"
fi

function find_current_file_absolute_path() {
	local D PWD="${__STARTUP_PWD}"
	D="${PWD}"
	while [[ ${D} != '/' ]]; do
		if [[ -e "${D}/${CURRENT_FILE}" ]]; then
			CURRENT_FILE=$(realpath "${D}/${CURRENT_FILE}")
			return
		fi
		D=$(dirname "${D}")
	done
	D="${COMMON_LIB_ROOT}"
	while [[ ${D} != '/' ]]; do
		if [[ -e "${D}/${CURRENT_FILE}" ]]; then
			CURRENT_FILE=$(realpath "${D}/${CURRENT_FILE}")
			return
		fi
		D=$(dirname "${D}")
	done

	D="${PWD}/$(basename "${CURRENT_FILE}")"
	if [[ -e ${D} ]]; then
		CURRENT_FILE=$(realpath "${D}")
		return
	fi

	die "can not find absolute path of \$0(${CURRENT_FILE}), in:\n - COMMON_LIB_ROOT=${COMMON_LIB_ROOT}\n - PWD=${PWD}\nBASH_SOURCE:\n$(printf ' * %s\n' "${BASH_SOURCE[@]}")"
}

if [[ ${CURRENT_FILE} != /* ]]; then
	find_current_file_absolute_path
else
	CURRENT_FILE=$(realpath "${CURRENT_FILE}")
fi
declare -xr CURRENT_FILE

if [[ ${CURRENT_DIR+found} != "found" ]]; then
	CURRENT_DIR="$(dirname "${CURRENT_FILE}")"
	if [[ ${CURRENT_DIR} == "." ]]; then
		echo "Error: can't get current script location." >&2
		exit 1
	fi
	if [[ "$(basename "${CURRENT_DIR}")" == "scripts" ]]; then
		CURRENT_DIR="$(dirname "${CURRENT_DIR}")"
	fi
fi
declare -xr CURRENT_DIR

if [[ ${PROJECT_NAME+found} != found ]]; then
	PROJECT_NAME="$(basename "${CURRENT_DIR}")"
fi
if [[ -n ${PROJECT_NAME} ]]; then
	declare -xr PROJECT_NAME
fi

MONO_ROOT_DIR=${GITHUB_WORKSPACE-"$(dirname "${COMMON_LIB_ROOT}")"}
if [[ -e "${MONO_ROOT_DIR}/.git" ]]; then
	declare -xr MONO_ROOT_DIR
	if [[ -e "${MONO_ROOT_DIR}/.env" ]]; then
		set -a
		# shellcheck source=/dev/null
		source "${MONO_ROOT_DIR}/.env"
		set +a
	fi
else
	unset MONO_ROOT_DIR
fi

if is_root; then
	declare -x SCRIPTS_DIR="/usr/local/libexec/${PROJECT_NAME}"
	declare -x SHARED_SCRIPTS_DIR="/usr/local/libexec/image-build-shared"
	declare -xr BINARY_DIR="/usr/local/bin"
else
	declare -x SCRIPTS_DIR="${HOME}/.local/libexec/${PROJECT_NAME}"
	declare -x SHARED_SCRIPTS_DIR="${HOME}/.local/libexec/image-build-shared"
	declare -xr BINARY_DIR="${HOME}/.local/bin"
fi

function set_script_root() {
	if is_root; then
		declare -gx SCRIPTS_DIR="/usr/local/libexec/$1"
	else
		declare -gx SCRIPTS_DIR="${HOME}/.local/libexec/$1"
	fi
}

if is_root; then
	if [[ ${TEST_MODE-} == yes ]]; then
		info_warn "runing in test mode"
		declare -r PODMAN_QUADLET_DIR="/run/containers/systemd"
		declare -r SYSTEM_UNITS_DIR="/run/systemd/system"
	else
		declare -r PODMAN_QUADLET_DIR="/etc/containers/systemd"
		declare -r SYSTEM_UNITS_DIR="/usr/local/lib/systemd/system"
	fi
else
	declare -r PODMAN_QUADLET_DIR="${HOME}/.config/containers/systemd"
	declare -r SYSTEM_UNITS_DIR="${HOME}/.config/systemd/user"
fi

if [[ "${CONTAINERS_DATA_PATH+found}" != "found" ]]; then
	export CONTAINERS_DATA_PATH="/data/AppData"
fi
declare -r CONTAINERS_DATA_PATH="${CONTAINERS_DATA_PATH}"
declare -r COMMON_LIB_ROOT="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
declare -r MONO_ROOT_DIR="$(dirname "$COMMON_LIB_ROOT")"
declare -r CURRENT_ACTION="$(basename "$(realpath -m "${BASH_SOURCE[-1]}")")"
declare -r CURRENT_DIR="$(dirname "$(realpath -m "${BASH_SOURCE[-1]}")")"
if [[ "$CURRENT_DIR" == "." ]] ; then
	echo "Error: can't get current script location.">&2
	exit 1
fi
PROJECT_NAME="$(basename "${CURRENT_DIR}")"

source "$COMMON_LIB_ROOT/functions/fs.sh"
source "$COMMON_LIB_ROOT/functions/output.sh"
source "$COMMON_LIB_ROOT/functions/arguments.sh"
source "$COMMON_LIB_ROOT/functions/download_file.sh"

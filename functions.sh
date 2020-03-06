COMMON_LIB_ROOT="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
MONO_ROOT_DIR="$(dirname "$COMMON_LIB_ROOT")"
CURRENT_ACTION="$(basename "$(realpath -m "${BASH_SOURCE[-1]}")")"
CURRENT_DIR="$(dirname "$(realpath -m "${BASH_SOURCE[-1]}")")"
if [[ "$CURRENT_DIR" == "." ]] ; then
	echo "Error: can't get current script location.">&2
	exit 1
fi
PROJECT_NAME="$(basename "${CURRENT_DIR}")"

source "$COMMON_LIB_ROOT/functions/output.sh"
source "$COMMON_LIB_ROOT/functions/arguments.sh"

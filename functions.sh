#!/usr/bin/env bash

if [[ ${__PRAGMA_ONCE_FUNCTIONS_SH+found} == found ]]; then
	return
fi
declare -r __PRAGMA_ONCE_FUNCTIONS_SH=yes

set -Eeuo pipefail
shopt -s lastpipe nullglob

declare -r __STARTUP_PWD=$(pwd)
COMMON_LIB_ROOT="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
declare -xr COMMON_LIB_ROOT

export __BASH_ARGV=("$@")
CURRENT_FILE="${BASH_SOURCE[-1]}"
if [[ ${CURRENT_FILE} == */bashdb ]]; then
	CURRENT_FILE="${BASH_SOURCE[-2]}"
fi
if [[ ${BASH_SOURCE[-1]} == */bashdb ]]; then
	CURRENT_ACTION="$(basename "$(realpath -m "${BASH_SOURCE[-2]}")" .sh)"
else
	CURRENT_ACTION="$(basename "$(realpath -m "${BASH_SOURCE[-1]}")" .sh)"
fi
declare -xr CURRENT_ACTION

if [[ ${UID:+f} != f ]]; then
	UID=$(id -u)
	declare -irx UID
fi
function is_root() {
	return "$UID"
}
function is_set() {
	declare -p "$1" &>/dev/null
}
function is_tty() {
	[[ -t ${1-1} ]]
}

pushd "$COMMON_LIB_ROOT" &>/dev/null

source "./functions/output.sh"

source "./init/constants.sh"
source "./init/paths.sh"

source "./functions/exit.sh"
source "./functions/fs.sh"
source "./functions/arguments.sh"
source "./functions/download_file.sh"
source "./functions/platform.sh"
source "./functions/proxy.sh"
source "./functions/temp.sh"
source "./functions/strings.sh"

popd &>/dev/null

function function_exists() {
	declare -F "$PREFIX_FN" >/dev/null
}

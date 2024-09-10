#!/usr/bin/env bash

if [[ ${__PRAGMA_ONCE_FUNCTIONS_SH+found} == found ]]; then
	return
fi
declare -r __PRAGMA_ONCE_FUNCTIONS_SH=yes

set -Eeuo pipefail
shopt -s lastpipe nullglob

# shellcheck disable=SC2155
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

pushd "$COMMON_LIB_ROOT" &>/dev/null

source "./init/platform.sh"
source "./init/strings.sh"
source "./init/output.sh"
source "./init/constants.sh"
source "./init/paths.sh"
source "./init/proxy.sh"

source "./functions/exit.sh"
source "./functions/fs.sh"
source "./functions/arguments.sh"
source "./functions/download_file.sh"
source "./functions/temp.sh"

popd &>/dev/null

_check_ci_env

#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit extglob nullglob globstar lastpipe shift_verbose

# shellcheck disable=SC2155
declare -r __STARTUP_PWD=$(pwd)
# shellcheck disable=SC2312
COMMON_LIB_ROOT="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
declare -xr COMMON_LIB_ROOT

export __BASH_ARGV=("$@")
CURRENT_FILE="${BASH_SOURCE[-1]}"
if [[ ${CURRENT_FILE} == */bashdb ]]; then
	CURRENT_FILE="${BASH_SOURCE[-2]}"
fi
if [[ ${BASH_SOURCE[-1]} == */bashdb ]]; then
	# shellcheck disable=SC2312
	CURRENT_ACTION="$(basename "$(realpath -m "${BASH_SOURCE[-2]}")" .sh)"
else
	# shellcheck disable=SC2312
	CURRENT_ACTION="$(basename "$(realpath -m "${BASH_SOURCE[-1]}")" .sh)"
fi
declare -xr CURRENT_ACTION

pushd "${COMMON_LIB_ROOT}/package" &>/dev/null

source "./init/0-lifecycle-dedup.sh"
source "./init/output.sh"
source "./init/basic.sh"
source "./init/strings.sh"
source "./init/constants.sh"
source "./init/paths.sh"
source "./init/exit.sh"
source "./init/arguments.sh"

source "./platform/proxy.sh"
source "./platform/systemctl.sh"
source "./platform/temp.sh"
source "./platform/filesystem.sh"
source "./platform/download-file.sh"
source "./platform/healthcheck.sh"
source "./platform/start-stop-reload.sh"
source "./platform/xrun.sh"

popd &>/dev/null

_check_ci_env

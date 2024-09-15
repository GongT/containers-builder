#!/usr/bin/env bash

# shellcheck disable=SC2155
declare -r __STARTUP_PWD=$(pwd)
# shellcheck disable=SC2312
COMMON_LIB_ROOT="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
declare -xr COMMON_LIB_ROOT

export __BASH_ARGV=("$@")
if [[ -z ${CURRENT_FILE-} ]]; then
	CURRENT_FILE="${BASH_SOURCE[-1]}"
	if [[ ${CURRENT_FILE} == */bashdb ]]; then
		CURRENT_FILE="${BASH_SOURCE[-2]}"
	fi
fi
if [[ ${BASH_SOURCE[-1]} == */bashdb ]]; then
	# shellcheck disable=SC2312
	CURRENT_ACTION="$(basename "$(realpath -m "${BASH_SOURCE[-2]}")" .sh)"
else
	# shellcheck disable=SC2312
	CURRENT_ACTION="$(basename "$(realpath -m "${BASH_SOURCE[-1]}")" .sh)"
fi
declare -xr CURRENT_ACTION

source "${COMMON_LIB_ROOT}/package/init/lifecycle-decoupling.sh"
source "${COMMON_LIB_ROOT}/package/init/basic.sh"
source "${COMMON_LIB_ROOT}/package/init/bash-error-handler.sh"
source "${COMMON_LIB_ROOT}/package/init/output.sh"
source "${COMMON_LIB_ROOT}/package/init/term.sh"
source "${COMMON_LIB_ROOT}/package/init/json.sh"
source "${COMMON_LIB_ROOT}/package/init/exit.sh"
source "${COMMON_LIB_ROOT}/package/init/strings.sh"
source "${COMMON_LIB_ROOT}/package/init/constants.sh"
source "${COMMON_LIB_ROOT}/package/init/paths.sh"
source "${COMMON_LIB_ROOT}/package/init/arguments.sh"
source "${COMMON_LIB_ROOT}/package/init/author-detect.sh"
source "${COMMON_LIB_ROOT}/package/platform/proxy.sh"
source "${COMMON_LIB_ROOT}/package/platform/systemctl.sh"
source "${COMMON_LIB_ROOT}/package/platform/temp.sh"
source "${COMMON_LIB_ROOT}/package/platform/filesystem.sh"
source "${COMMON_LIB_ROOT}/package/platform/download-file.sh"
source "${COMMON_LIB_ROOT}/package/platform/healthcheck.sh"
source "${COMMON_LIB_ROOT}/package/platform/start-stop-reload.sh"
source "${COMMON_LIB_ROOT}/package/platform/xrun.sh"
source "${COMMON_LIB_ROOT}/package/platform/mount-script-run.sh"

_check_ci_env
use_normal

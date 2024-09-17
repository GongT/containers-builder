#!/usr/bin/env bash

if [[ ${__PRAGMA_ONCE_FUNCTIONS_INSTALL_SH+found} == found ]]; then
	return
fi
declare -r __PRAGMA_ONCE_FUNCTIONS_INSTALL_SH=yes

# shellcheck source=package/include.sh disable=SC2312
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/include.sh"

source "${COMMON_LIB_ROOT}/package/container-install/engine-params.sh"
source "${COMMON_LIB_ROOT}/package/container-install/networking.sh"
source "${COMMON_LIB_ROOT}/package/container-install/pod.sh"
source "${COMMON_LIB_ROOT}/package/container-install/environments.sh"
source "${COMMON_LIB_ROOT}/package/container-install/volumes.sh"
source "${COMMON_LIB_ROOT}/package/container-install/systemd.sh"
source "${COMMON_LIB_ROOT}/package/container-install/commandline.sh"
source "${COMMON_LIB_ROOT}/package/container-install/systemd.service.sh"
source "${COMMON_LIB_ROOT}/package/container-install/image-pull.sh"
source "${COMMON_LIB_ROOT}/package/container-install/install-script.sh"
source "${COMMON_LIB_ROOT}/package/container-install/capability.sh"
source "${COMMON_LIB_ROOT}/package/container-install/services.sh"
source "${COMMON_LIB_ROOT}/package/container-install/service-wait.sh"

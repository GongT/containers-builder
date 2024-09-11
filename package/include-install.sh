#!/usr/bin/env bash

if [[ ${__PRAGMA_ONCE_FUNCTIONS_INSTALL_SH+found} == found ]]; then
	return
fi
declare -r __PRAGMA_ONCE_FUNCTIONS_INSTALL_SH=yes

# shellcheck source=package/include.sh disable=SC2312
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/include.sh"

pushd "${COMMON_LIB_ROOT}/package" &>/dev/null

source "./container-install/networking.sh"
source "./container-install/pod.sh"
source "./container-install/environments.sh"
source "./container-install/volumes.sh"
source "./container-install/systemd.sh"
source "./container-install/systemd.service.sh"
source "./container-install/image-pull.sh"
source "./container-install/install-script.sh"
source "./container-install/uninstall.sh"
source "./container-install/capability.sh"
source "./container-install/services.sh"
source "./container-install/service-wait.sh"

popd &>/dev/null

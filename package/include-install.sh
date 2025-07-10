#!/usr/bin/env bash

if [[ ${__PRAGMA_ONCE_FUNCTIONS_INSTALL_SH+found} == found ]]; then
	return
fi
declare -r __PRAGMA_ONCE_FUNCTIONS_INSTALL_SH=yes

# shellcheck source=./include.sh disable=SC2312
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/include.sh"

pushd "${COMMON_LIB_ROOT}/package" &>/dev/null
source "./container-install/engine-params.sh"
source "./container-install/networking.sh"
source "./container-install/pod.sh"
source "./container-install/environments.sh"
source "./container-install/volumes.sh"
source "./container-install/systemd.sh"
source "./container-install/commandline.sh"
source "./container-install/systemd.service.sh"
source "./container-install/image-pull.sh"
source "./container-install/install-script.sh"
source "./container-install/capability.sh"
source "./container-install/services.sh"
source "./container-install/service-wait.sh"
popd &>/dev/null

find "${COMMON_LIB_ROOT}/staff/systemd-filesystem" -mindepth 2 -maxdepth 2 -name 'install.hook.sh' -print0 | while read -d '' -r FILE; do
	# shellcheck source=/dev/null
	source "${FILE}"
done
unset FILE

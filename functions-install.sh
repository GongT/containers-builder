#!/usr/bin/env bash

if [[ ${__PRAGMA_ONCE_FUNCTIONS_INSTALL_SH+found} == found ]]; then
	return
fi
declare -r __PRAGMA_ONCE_FUNCTIONS_INSTALL_SH=yes

# shellcheck source=./functions.sh
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/functions.sh"

PODMAN=$(find_command podman || die "podman not installed")
declare -rx PODMAN

pushd "$COMMON_LIB_ROOT" &>/dev/null
source "./functions/networking.sh"
source "./functions/environments.sh"
source "./functions/volumes.sh"
source "./functions/systemd.sh"
source "./functions/systemd.slices.sh"
source "./functions/install.sh"
source "./functions/uninstall.sh"
source "./functions/cap.sh"
source "./functions/healthcheck.sh"
source "./functions/custom-stop-reload.sh"
source "./services.sh"
popd &>/dev/null

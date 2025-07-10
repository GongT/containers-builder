#!/usr/bin/env bash

if [[ ${__PRAGMA_ONCE_FUNCTIONS_BUILD_SH+found} == found ]]; then
	return
fi
declare -r __PRAGMA_ONCE_FUNCTIONS_BUILD_SH=yes

# shellcheck source=./include.sh disable=SC2312
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/include.sh"

# declare -r FEDORA_SYSTEMD_COMMAND='/lib/systemd/systemd --system --log-target=console --show-status=yes --log-color=no systemd.journald.forward_to_console=yes'

pushd "${COMMON_LIB_ROOT}/package" &>/dev/null
source "./image-build/base-image.sh"
source "./image-build/container-helpers.sh"
source "./image-build/container-create.sh"
source "./image-build/mdnf.sh"
source "./image-build/mcompile.sh"
source "./image-build/buildah-cache.sh"
source "./image-build/buildah-cache.remote.sh"
source "./image-build/build-folder-hash.sh"
source "./image-build/final-config-helper.sh"
source "./image-build/buildah.hooks.sh"
source "./image-build/alpine.sh"
source "./image-build/apt-get.sh"
source "./image-build/archlinux.sh"
source "./image-build/python.sh"
source "./image-build/oci-labels.sh"
source "./image-build/make-steps.sh"

source "./standard_build_steps/container-systemd.sh"
source "./standard_build_steps/download_and_build_github.sh"
source "./standard_build_steps/install_build_result.sh"
source "./standard_build_steps/merge_local_fs.sh"
source "./standard_build_steps/x64init.sh"
popd &>/dev/null

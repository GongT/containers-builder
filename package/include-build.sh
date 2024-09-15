#!/usr/bin/env bash

if [[ ${__PRAGMA_ONCE_FUNCTIONS_BUILD_SH+found} == found ]]; then
	return
fi
declare -r __PRAGMA_ONCE_FUNCTIONS_BUILD_SH=yes

# shellcheck source=package/include.sh disable=SC2312
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/include.sh"

# declare -r FEDORA_SYSTEMD_COMMAND='/lib/systemd/systemd --system --log-target=console --show-status=yes --log-color=no systemd.journald.forward_to_console=yes'

source "${COMMON_LIB_ROOT}/package/image-build/base-image.sh"
source "${COMMON_LIB_ROOT}/package/image-build/container-helpers.sh"
source "${COMMON_LIB_ROOT}/package/image-build/container-create.sh"
source "${COMMON_LIB_ROOT}/package/image-build/mdnf.sh"
source "${COMMON_LIB_ROOT}/package/image-build/mcompile.sh"
source "${COMMON_LIB_ROOT}/package/image-build/buildah-cache.sh"
source "${COMMON_LIB_ROOT}/package/image-build/build-folder-hash.sh"
source "${COMMON_LIB_ROOT}/package/image-build/buildah-cache.fork.sh"
source "${COMMON_LIB_ROOT}/package/image-build/final-config-helper.sh"
source "${COMMON_LIB_ROOT}/package/image-build/buildah-cache.helper.run.sh"
source "${COMMON_LIB_ROOT}/package/image-build/buildah-cache.remote.sh"
source "${COMMON_LIB_ROOT}/package/image-build/buildah.hooks.sh"
source "${COMMON_LIB_ROOT}/package/image-build/alpine.sh"
source "${COMMON_LIB_ROOT}/package/image-build/apt-get.sh"
source "${COMMON_LIB_ROOT}/package/image-build/archlinux.sh"
source "${COMMON_LIB_ROOT}/package/image-build/python.sh"
source "${COMMON_LIB_ROOT}/package/image-build/mount-script-run.sh"
source "${COMMON_LIB_ROOT}/package/image-build/oci-labels.sh"
source "${COMMON_LIB_ROOT}/package/image-build/make-steps.sh"

source "${COMMON_LIB_ROOT}/package/standard_build_steps/container-systemd.sh"
source "${COMMON_LIB_ROOT}/package/standard_build_steps/download_and_build_github.sh"
source "${COMMON_LIB_ROOT}/package/standard_build_steps/install_build_result.sh"
source "${COMMON_LIB_ROOT}/package/standard_build_steps/merge_local_fs.sh"
source "${COMMON_LIB_ROOT}/package/standard_build_steps/x64init.sh"

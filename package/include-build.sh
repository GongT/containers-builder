#!/usr/bin/env bash

# shellcheck source=package/include.sh disable=SC2312
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/package/include.sh"

# declare -r FEDORA_SYSTEMD_COMMAND='/lib/systemd/systemd --system --log-target=console --show-status=yes --log-color=no systemd.journald.forward_to_console=yes'

pushd "${COMMON_LIB_ROOT}" &>/dev/null

source "./image-build/mdnf.sh"
source "./image-build/mcompile.sh"
source "./image-build/buildah-cache.sh"
source "./image-build/build-folder-hash.sh"
source "./image-build/buildah-cache.2.sh"
source "./image-build/buildah-cache.fork.sh"
source "./image-build/buildah-cache.helper.config.sh"
source "./image-build/buildah-cache.helper.run.sh"
source "./image-build/buildah-cache.remote.sh"
source "./image-build/buildah.hooks.sh"
source "./image-build/alpine.sh"
source "./image-build/apt-get.sh"
source "./image-build/archlinux.sh"
source "./image-build/python.sh"
source "./image-build/build-folder-hash.sh"
source "./image-build/healthcheck.sh"
source "./image-build/custom-stop-reload.sh"
source "./image-build/container-systemd.sh"

source "./standard_build_steps/download_and_build_github.sh"
source "./standard_build_steps/install_build_result.sh"
source "./standard_build_steps/merge_local_fs.sh"
source "./standard_build_steps/x64init.sh"

popd &>/dev/null

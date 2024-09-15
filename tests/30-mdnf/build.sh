#!/usr/bin/env bash

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export PROJECT_NAME="mdnf-build-test"
source ../../functions-build.sh
guard_no_root

dnf_use_environment

buildah_cache_start "fedora-minimal"

dnf_install_step "$PROJECT_NAME" pkgs/bash.lst

buildah_finalize_image "$PROJECT_NAME" "$PROJECT_NAME"

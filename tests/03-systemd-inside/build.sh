#!/usr/bin/env bash

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export PROJECT_NAME="systemd-inside"
source ../../functions-build.sh
guard_no_root

buildah_cache_start fedora-minimal
dnf_install "$PROJECT_NAME" scripts/requirements.lst

merge_local_fs "$PROJECT_NAME" scripts/prepare-fs.sh

setup_systemd "$PROJECT_NAME" \
	enable UNITS="sleep.service fail.service"

buildah_finalize_image "$PROJECT_NAME" "$PROJECT_NAME"

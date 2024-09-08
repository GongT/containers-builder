#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export PROJECT_NAME="test-wait-logic"
source ../../../functions-build.sh
guard_no_root

buildah_cache_start fedora:latest
dnf_install "$PROJECT_NAME" scripts/requirements.lst

merge_local_fs "$PROJECT_NAME" fs

buildah_config "$PROJECT_NAME" --entrypoint=/opt/entrypoint.sh

buildah_finalize_image "$PROJECT_NAME" "$PROJECT_NAME"

#!/usr/bin/env bash

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export PROJECT_NAME="test-wait-logic"
source ../../functions-build.sh
guard_no_root

buildah_cache_start fedora:latest
dnf_install "$PROJECT_NAME" scripts/requirements.lst

merge_local_fs "$PROJECT_NAME"

buildah_config "$PROJECT_NAME" --entrypoint=/opt/entrypoint.sh --cmd '[]'

healthcheck /opt/healthcheck.sh
healthcheck_retry 5
healthcheck_startup 10s 5s
healthcheck_timeout 2s
healthcheck_interval 10min

buildah_finalize_image "$PROJECT_NAME" "$PROJECT_NAME"

#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export PROJECT_NAME="simple-build"
source ../../functions-build.sh
guard_no_root

buildah_cache_start fedora:latest

merge_local_fs "$PROJECT_NAME"

buildah_config "$PROJECT_NAME" '--cmd=["arg1"]' '--entrypoint=["/opt/test-entry.sh"]'
custom_reload_command bash /opt/testcmd.sh reload
custom_stop_command bash /opt/testcmd.sh stop

buildah_finalize_image "$PROJECT_NAME" "$PROJECT_NAME"

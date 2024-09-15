#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export PROJECT_NAME="basic-install"
source ../../functions-install.sh
guard_no_root

arg_finish "$@"

create_pod_service_unit simple-build
unit_unit Description this is basic test
network_use_default 6666
systemd_slice_type normal
unit_podman_cmdline arg1 arg2 arg3 "wow, such doge"

environment_variable \
	"USERNAME=foo"

unit_fs_bind logs /var/log/all
shared_sockets_use

unit_finish

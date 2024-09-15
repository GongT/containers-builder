#!/usr/bin/env bash

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export PROJECT_NAME="test-wait-logic"
source ../../functions-install.sh
guard_no_root

arg_finish "$@"

create_pod_service_unit systemd-container
unit_podman_image "systemd-inside"
network_use_veth podman 12345/tcp
unit_unit Description systemd container test
unit_start_notify pass
unit_podman_image_pull never
unit_finish

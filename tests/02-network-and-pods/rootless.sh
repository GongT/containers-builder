#!/usr/bin/env bash

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export PROJECT_NAME="test-wait-logic"
source ../../functions-install.sh
guard_no_root

arg_finish "$@"

network_define_nat "podman6" 10.66.77.0/24
network_provide_pod infra veth:podman6

create_pod_service_unit net-depend
unit_unit Description depend on network podman6
unit_podman_image_pull never
network_use_pod infra
unit_finish

systemctl daemon-reload

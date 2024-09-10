#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export PROJECT_NAME="test-wait-logic"
source ../../functions-install.sh
guard_no_root

arg_finish "$@"

create_pod_service_unit tsb-sleep1
unit_unit Description test wait sleep
unit_start_notify sleep 10
unit_podman_image_pull never
unit_finish

create_pod_service_unit tsb-sleep2
unit_unit Description this will never success
unit_start_notify sleep 20
unit_podman_image_pull never
unit_finish

create_pod_service_unit tsb-output
unit_unit Description test wait output message
unit_start_notify output "success when see this message"
unit_podman_image_pull never
unit_finish

create_pod_service_unit tsb-touch
unit_unit Description test wait file exists
unit_start_notify touch "/some/file/in/container"
unit_podman_image_pull never
unit_finish

create_pod_service_unit tsb-port
unit_unit Description test wait port listen
network_use_auto
unit_start_notify port 12345/udp
unit_podman_image_pull never
unit_finish

create_pod_service_unit tsb-socket
unit_unit Description test wait socket listen
shared_sockets_provide the-socket.sock
unit_start_notify socket
unit_podman_image_pull never
unit_finish

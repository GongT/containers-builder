#!/usr/bin/env bash

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export PROJECT_NAME="test-wait-logic"
source ../../functions-install.sh
guard_no_root

export DEFAULT_USED_NETWORK=veth
arg_finish "$@"

create_pod_service_unit tsb-sleep1
unit_unit Description test wait sleep
start_notify sleep 10
unit_podman_image_pull never
unit_podman_image test-wait-logic sleep
unit_finish

create_pod_service_unit tsb-sleep2
unit_unit Description this will never success
start_notify sleep 20
unit_podman_image_pull never
unit_podman_image test-wait-logic sleep
unit_finish

create_pod_service_unit tsb-output
unit_unit Description test wait output message
start_notify output "success when see this message"
unit_podman_image_pull never
unit_podman_image test-wait-logic output
unit_finish

create_pod_service_unit tsb-touch
unit_unit Description test wait file exists
start_notify touch "/some/file/in/container"
unit_podman_image_pull never
unit_podman_image test-wait-logic touch
unit_finish

create_pod_service_unit tsb-port
unit_unit Description test wait port listen
network_use_veth
start_notify port 12345/udp
unit_podman_image_pull never
unit_podman_image test-wait-logic port
unit_finish

create_pod_service_unit tsb-socket
unit_unit Description test wait socket listen
shared_sockets_provide the-socket.sock
start_notify socket
unit_podman_image_pull never
unit_podman_image test-wait-logic socket
unit_finish

create_pod_service_unit tsb-healthy
unit_unit Description test wait socket listen
start_notify healthy
unit_podman_image_pull never
unit_podman_image test-wait-logic healthy
unit_finish

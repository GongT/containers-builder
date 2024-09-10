#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export PROJECT_NAME="test-wait-logic"
source ../../functions-install.sh
guard_no_root

arg_finish "$@"

network_define_nat "podman6" 10.66.77.0/24
network_provide_pod infra veth:bridge0

systemctl daemon-reload

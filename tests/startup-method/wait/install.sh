#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export PROJECT_NAME="test-wait-logic"
source ../../../functions-install.sh
guard_no_root

arg_finish "$@"

create_pod_service_unit test-script-builder
unit_unit Description this is a test
network_use_auto
unit_start_notify sleep 10
unit_finish

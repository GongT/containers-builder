#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export PROJECT_NAME="test-wait-logic"
source ../../functions-install.sh
guard_root_only

arg_finish "$@"

network_define_bridge_interface "bridge0"

systemctl daemon-reload

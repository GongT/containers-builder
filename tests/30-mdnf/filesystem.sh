#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export PROJECT_NAME="test-dnf"
source ../../functions-build.sh
guard_no_root

CID=$(new_container test scratch)
collect_temp_container "${CID}"

dnf_use_environment
call_dnf_install "${CID}" pkgs/filesystem.lst
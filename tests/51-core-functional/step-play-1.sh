#!/usr/bin/env bash

set -Eeuo pipefail

declare -xr _BUILDSCRIPT_RUN_STEP_='simple-build:1'

# shellcheck source=/dev/null disable=SC2312
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/simple.sh"

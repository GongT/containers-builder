#!/usr/bin/env bash

# shellcheck source=./functions.sh
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/functions.sh"

BUILDAH="$(find_command buildah)"
declare -rx BUILDAH

# shellcheck source=./functions/networking.sh
source "$COMMON_LIB_ROOT/functions/networking.sh"
# shellcheck source=./functions/environments.sh
source "$COMMON_LIB_ROOT/functions/environments.sh"
# shellcheck source=./functions/systemd.sh
source "$COMMON_LIB_ROOT/functions/systemd.sh"
# shellcheck source=./functions/install.sh
source "$COMMON_LIB_ROOT/functions/install.sh"
# shellcheck source=./functions/uninstall.sh
source "$COMMON_LIB_ROOT/functions/uninstall.sh"
# shellcheck source=./functions/cap.sh
source "$COMMON_LIB_ROOT/functions/cap.sh"

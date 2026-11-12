#!/usr/bin/bash

set -Eeuo pipefail
shopt -s inherit_errexit extglob nullglob globstar lastpipe shift_verbose

_loader_file="$(realpath "${BASH_SOURCE[0]}")"

# shellcheck source=./log.sh
source "/entrypoint/library/log.sh"
# shellcheck source=./env.sh
source "/entrypoint/library/env.sh"
# shellcheck source=./users.sh
source "/entrypoint/library/users.sh"
# shellcheck source=./filesystem.sh
source "/entrypoint/library/filesystem.sh"

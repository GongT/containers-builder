#!/usr/bin/env bash

# shellcheck disable=SC2312
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
declare -xr PROJECT_NAME="image-builder-cli"
source "./package/include-install.sh"
cd cli

arg_finish

mkdir -p "${SCRIPTS_DIR}"
rsync --itemize-changes --archive --human-readable "${PWD}/cli-lib" "${SCRIPTS_DIR}" --delete

install_global_binary "${PWD}/bin.sh" "ms"  

echo "${PWD}" >"${SCRIPTS_DIR}/cli-home"

echo "binary installed to ${BINARY_DIR}/ms"
echo "library installed to ${SCRIPTS_DIR}"

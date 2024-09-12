#!/usr/bin/env bash

# shellcheck disable=SC2312
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
declare -xr PROJECT_NAME="image-builder-cli"
source "./package/include.sh"
cd cli

mkdir -p "${SCRIPTS_DIR}"
rsync --itemize-changes --archive --human-readable "${PWD}/cli-lib" "${SCRIPTS_DIR}" --delete
{
	SHELL_SCRIPT_PREFIX
	cat bin.sh
} >"${BINARY_DIR}/ms"

echo "${PWD}" >"${SCRIPTS_DIR}/cli-home"

chmod a+x "${BINARY_DIR}/ms"

echo "binary installed to ${BINARY_DIR}/ms"
echo "library installed to ${SCRIPTS_DIR}"

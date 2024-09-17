#!/usr/bin/env bash

declare -xr PROJECT_NAME="image-builder-cli"
# shellcheck source=package/include-install.sh disable=SC2312
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/package/include-install.sh"

arg_finish

mkdir -p "${SCRIPTS_DIR}"

TMPF=$(create_temp_file "ms.binary.sh")

{
	echo '#!/usr/bin/bash'
	echo 'source "../package/include.sh"'
	find "${COMMON_LIB_ROOT}/cli/library" -type f | while read -r FILE; do
		cat_source_file "${FILE}"
	done

	find "${COMMON_LIB_ROOT}/cli/actions" -type f | while read -r FILE; do
		cat_source_file "${FILE}"
	done
	cat_source_file "${COMMON_LIB_ROOT}/cli/bin.sh"
} >"${TMPF}"

install_global_binary "${TMPF}" "ms"

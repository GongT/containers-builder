#!/bin/bash

mapfile -d ' ' -t REQ_ARR < <(printf '%s' "${REQUIRE-}")
mapfile -d ' ' -t WANT_ARR < <(printf '%s' "${WANT-}")

declare -r SOURCE_DIR="/etc/systemd/my/enable"
mkdir -p "${SOURCE_DIR}"

# shellcheck disable=SC2086
x systemctl enable ${REQUIRE-} ${WANT-}

# shellcheck disable=SC2086
if [[ -n ${REQUIRE-} ]]; then
	printf "%s\n" ${REQUIRE-} >>"${SOURCE_DIR}/requires"
fi

# shellcheck disable=SC2086
if [[ -n ${WANT-} ]]; then
	printf "%s\n" ${WANT-} >>"${SOURCE_DIR}/wants"
fi

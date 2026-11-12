#!/usr/bin/bash

# 由于service名称绝不会出现空格，因此可以用空格分割成数组
if [[ -n "${REQUIRE-}" ]]; then
	mapfile -d ' ' -t REQ_ARR < <(printf '%s' "${REQUIRE-}")
else
	declare -a REQ_ARR=()
fi
if [[ -n "${WANT-}" ]]; then
	mapfile -d ' ' -t WANT_ARR < <(printf '%s' "${WANT-}")
else
	declare -a WANT_ARR=()
fi

OUT_DIR=/entrypoint/systemd.enables.d
mkdir -p "${OUT_DIR}/requires" "${OUT_DIR}/wants"

for req in "${REQ_ARR[@]}"; do
	touch "${OUT_DIR}/requires/${req}"
done
for want in "${WANT_ARR[@]}"; do
	touch "${OUT_DIR}/wants/${want}"
done

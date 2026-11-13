#!/usr/bin/bash

# 由于service名称绝不会出现空格，因此可以用空格分割成数组
if [[ -n ${REQUIRE-}   ]]; then
	mapfile -d ' ' -t REQ_ARR < <(printf '%s' "${REQUIRE-}")
else
	declare -a REQ_ARR=()
fi
if [[ -n ${WANT-}   ]]; then
	mapfile -d ' ' -t WANT_ARR < <(printf '%s' "${WANT-}")
else
	declare -a WANT_ARR=()
fi
if [[ -n ${BACKGROUND-}   ]]; then
	mapfile -d ' ' -t BG_ARR < <(printf '%s' "${BACKGROUND-}")
else
	declare -a BG_ARR=()
fi

mkdir -p /entrypoint/systemd.d
declare -p REQ_ARR WANT_ARR BG_ARR >/entrypoint/systemd.d/enable.sh

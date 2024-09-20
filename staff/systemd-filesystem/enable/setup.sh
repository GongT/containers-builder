#!/bin/bash

mapfile -d ' ' -t REQ_ARR < <(printf '%s' "${REQUIRE}")
mapfile -d ' ' -t WANT_ARR < <(printf '%s' "${WANT}")

mkdir -p /etc/systemd/system/success.service.d
OVERWRITE=/etc/systemd/system/success.service.d/plugin-enable.conf
echo '[Unit]' >"${OVERWRITE}"

if [[ ${#REQ_ARR[@]} -eq 0 && ${#WANT_ARR[@]} -eq 0 ]]; then
	die "systemd enable must have params (REQUIRE/WANT)"
fi
x systemctl enable "${REQ_ARR[@]}" "${WANT_ARR[@]}"

if [[ ${#REQ_ARR[@]} -ne 0 ]]; then
	echo "After=${REQ_ARR[*]}" >>"${OVERWRITE}"
	echo "Requires=${REQ_ARR[*]}" >>"${OVERWRITE}"
fi

if [[ ${#WANT_ARR[@]} -ne 0 ]]; then
	echo "After=${WANT_ARR[*]}" >>"${OVERWRITE}"
	echo "Wants=${WANT_ARR[*]}" >>"${OVERWRITE}"
fi

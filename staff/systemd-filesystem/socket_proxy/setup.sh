#!/usr/bin/env bash

if [[ -z ${PORTS} ]]; then
	die "missing required config: PORTS=[sock1:]12345[/tcp] ..."
fi

declare -r SOURCE_DIR="/etc/systemd/my/sockets"

# shellcheck disable=SC2206
PORTS_ARR=(${PORTS})

for PORTDEF in "${PORTS_ARR[@]}"; do
	NAME="${PORTDEF%:*}"
	VALUE="${PORTDEF#*:}"

	if [[ ${NAME} == "${VALUE}" ]]; then
		NAME=''
	fi

	PROTO="${VALUE#*/}"
	PORT="${VALUE%/*}"
	if [[ ${PROTO} == "${PORT}" ]]; then
		PROTO='tcp'
	fi

	if [[ ${PROTO} == tcp ]]; then
		# LISTEN_NAME="ListenStream"
		:
	elif [[ ${PROTO} == udp ]]; then
		# LISTEN_NAME="ListenDatagram"
		die "udp forwarding currently not implement"
	else
		die "invalid port proto: ${PORTDEF}: ${NAME} - ${PORT} - ${PROTO}"
	fi

	if [[ -z ${NAME} ]]; then
		FNAME="unnamed"
	else
		FNAME="${NAME}"
	fi

	mkdir -p "${SOURCE_DIR}"
	if [[ -e "${SOURCE_DIR}/${FNAME}" ]]; then
		die "duplicate proxy socket name: ${FNAME}"
	fi
	declare -p PROTO PORT NAME >"${SOURCE_DIR}/${FNAME}"
done

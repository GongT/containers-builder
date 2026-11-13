#!/usr/bin/env bash

if [[ -z ${PORTS} ]]; then
	die "缺少必要输入参数: PORTS=[sock1:]12345[/tcp] ..."
fi

declare -r SOURCE_DIR="/entrypoint/systemd.sockets.d/"
mkdir -p "${SOURCE_DIR}"

# shellcheck disable=SC2206
PORTS_ARR=(${PORTS})

for PORTDEF in "${PORTS_ARR[@]}"; do
	NAME="${PORTDEF%:*}"
	VALUE="${PORTDEF#*:}"
	PROTO="${VALUE#*/}"
	PORT="${VALUE%/*}"

	if [[ ${NAME} == "${VALUE}" ]]; then
		# 没有":"
		NAME="${VALUE}"
	fi

	if [[ ${PROTO} == "${PORT}" ]]; then
		# 没有"/"
		PROTO='tcp'
	fi

	if [[ ${PROTO} == tcp ]]; then
		# LISTEN_NAME="ListenStream"
		:
	elif [[ ${PROTO} == udp ]]; then
		# LISTEN_NAME="ListenDatagram"
		die "udp 转发暂未实现"
	else
		die "未知端口协议: ${PORTDEF}: ${NAME} - ${PORT} - ${PROTO}"
	fi

	if [[ -e "${SOURCE_DIR}/${NAME}" ]]; then
		die "重复的代理 socket 名称: ${NAME}"
	fi
	declare -p PROTO PORT NAME >"${SOURCE_DIR}/${NAME}"
done

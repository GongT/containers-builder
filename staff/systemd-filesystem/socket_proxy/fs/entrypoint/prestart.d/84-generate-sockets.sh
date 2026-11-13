#!/usr/bin/bash

function make_socket() {
	local PROTO PORT NAME
	# shellcheck source=/dev/null
	source "$1"

	local SOCKET_FILE="${SHARED_SOCKET_PATH}/${CONTAINER_ID}.${FNAME}.sock"

	local LISTEN_NAME="proxy-from-${NAME}.socket"
	local SERVICE_NAME="proxy-to-${PROTO}-${PORT}.service"

	local FILE_KIND
	if [[ ${PROTO} == "udp" ]]; then
		FILE_KIND="ListenDatagram"
	else
		FILE_KIND="ListenStream"
	fi

	cat >"/etc/systemd/system/${LISTEN_NAME}" <<-EOF
		# 本文件由 ${CONFIG_FILE} 生成
		[Unit]
		Description=将 ${SOCKET_FILE} 转发给 ${SERVICE_NAME}

		[Socket]
		${FILE_KIND}=${SOCKET_FILE}
		Service=${SERVICE_NAME}
	EOF
	cat >"/etc/systemd/system/${SERVICE_NAME}" <<-EOF
		# 本文件由 ${CONFIG_FILE} 生成
		[Unit]
		Description=代理输入到 ${PORT} (${PROTO})

		[Service]
		Type=notify
		ExecStart=/usr/lib/systemd/systemd-socket-proxyd 127.0.0.1:${PORT}
	EOF

	systemd_unit_critical "${LISTEN_NAME}"
}

function generate() {
	local SOURCE_DIR="/entrypoint/systemd.sockets.d/"

	if [[ ! -d ${SHARED_SOCKET_PATH} ]]; then
		echo "未挂载 sockets 文件目录: ${SHARED_SOCKET_PATH}" >/dev/kmsg
		exit 0
	fi

	local FILES=()
	walk_dir FILES "${SOURCE_DIR}"
	for FILE in "${FILES[@]}"; do
		make_socket "$FILE"
	done
}

generate
unset -f make_socket generate

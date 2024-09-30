#!/usr/bin/env bash

if [[ -z ${PORTS} ]]; then
	die "missing required config: PORTS=[sock1:]12345[/tcp] ..."
fi

mapfile -t PORTS_ARR < <(echo "${PORTS}")

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
		LISTEN_NAME="ListenStream"
	elif [[ ${PROTO} == udp ]]; then
		LISTEN_NAME="ListenDatagram"
		die "udp forwarding currently not implement"
	else
		die "invalid port proto: ${PORTDEF}"
	fi

	if [[ -z ${NAME} ]]; then
		FNAME="${PROJECT_NAME}"
	else
		FNAME="${PROJECT_NAME}.${NAME}"
	fi

	cat >"/etc/systemd/system/${FNAME}.socket" <<-EOF
		[Unit]
		Description=proxy socket proxy for ${PROJECT_NAME} (${PROTO} ${NAME} ${PORT})
		FailureAction=exit
		FailureActionExitStatus=233
		Before=success.service

		[Install]
		WantedBy=sockets.target
		RequiredBy=success.service

		[Socket]
		${LISTEN_NAME}=/run/sockets/${FNAME}.sock
	EOF
	cat >"/etc/systemd/system/${FNAME}.service" <<-EOF
		[Unit]
		FailureAction=exit
		FailureActionExitStatus=233

		[Service]
		Type=notify
		ExecStart=/usr/lib/systemd/systemd-socket-proxyd 127.0.0.1:${PORT}
	EOF

	systemctl enable "${FNAME}.socket"
done

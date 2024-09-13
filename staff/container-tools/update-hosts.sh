#!/usr/bin/env bash

set -Eeuo pipefail

declare -r HOSTFILE=/etc/hosts

function info() {
	echo "{update-hosts} $*" >&2
}
function is_file_ending_newline() {
	local FILE="$1"
	test $(tail -c 1 "${FILE}" | wc -l) -eq 0
}
function is_file_need_newline() {
	local FILE="$1"
	if [[ ! -f ${FILE} ]]; then
		return 1
	fi
	if [[ $(wc -c <"${FILE}") -eq 0 ]]; then
		return 1
	fi
	is_file_ending_newline "${FILE}"
}
function append_text_file_line() {
	local FILE="$1"
	local COMMENT_TYPE="$2"
	local MARKUP="$3"
	local CONTENT="$4"

	if [[ ${CONTENT} == *$"\n"* ]]; then
		echo "[append_text_file_line] Error: content must have only one line" >&2
		return 1
	fi

	local TAG=" ${COMMENT_TYPE}${COMMENT_TYPE} ${MARKUP}"
	local PATTERN="${TAG}$"
	local SAFE_PATT="${PATTERN//\//\\/}"
	if grep -q "${SAFE_PATT}" "${FILE}"; then
		CONTENT="${CONTENT//'\'/'\\'}"
		sed -i "s/^.*${SAFE_PATT}/${CONTENT}${TAG}/g" "${FILE}"
	else
		if is_file_need_newline "${FILE}"; then
			echo "" >>"${FILE}"
		fi
		echo "${CONTENT}${TAG}" >>"${FILE}"
	fi
}

TAG="auto:${CONTAINER_ID}"
OLD_VALUE=$(grep --fixed-strings " ### ${TAG}" "${HOSTFILE}" | grep -Eo '^\S+' || echo '')

function signal_dnsmasq() {
	info "send SIGHUP to dnsmasq..."
	PID_DNS=$(systemctl show --property MainPID --value dnsmasq)
	if [[ ${PID_DNS} -gt 0 ]]; then
		kill -s SIGHUP "${PID_DNS}" || true
		info 'sent SIGHUP to dnsmasq.'
	else
		info "dnsmasq not running."
	fi
}

function add() {
	local IP=$(podman container inspect "${CONTAINER_ID}" --format '{{.NetworkSettings.IPAddress}}' || echo '')
	info "bind ip address ${IP} with ${CONTAINER_ID}"
	if [[ ${IP} == "${OLD_VALUE}" ]]; then
		info 'ip is same.'
		return
	elif [[ -z ${IP} ]]; then
		IP='# ip not found'
	fi

	append_text_file_line "${HOSTFILE}" '#' "${TAG}" "${IP} ${CONTAINER_ID} ${MY_HOSTNAME-}"
	info 'ok.'
	signal_dnsmasq
}

function del() {
	info "remove ip address of ${CONTAINER_ID}"
	append_text_file_line "${HOSTFILE}" '#' "${TAG}" ""
	info 'ok.'
	signal_dnsmasq
}

if [[ $1 == "add" ]]; then
	add
elif [[ $1 == "del" ]]; then
	del
else
	echo "unknown value: $1"
fi

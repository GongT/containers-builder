#!/usr/bin/env bash

if [[ -z ${PROXY-} ]]; then
	PROXY=${https_proxy-}
fi
if [[ -n ${PROXY} && ${PROXY} != http://* && ${PROXY} != https://* ]]; then
	PROXY="http://${PROXY}"
fi
declare -xr PROXY

info_note "using PROXY=${PROXY-*not set*}"

function SHELL_USE_PROXY() {
	if [[ -n ${PROXY-} ]]; then
		echo "PROXY=${PROXY}"
	else
		echo "PROXY="
	fi
	# shellcheck disable=SC2016
	echo '
if [[ -n "$PROXY" ]]; then
	export http_proxy="$PROXY"
	export https_proxy="$PROXY"
fi
'
}

function perfer_proxy() {
	if [[ -n ${PROXY-} ]]; then
		info_note "[proxy] using proxy ${PROXY}"
		http_proxy="${PROXY}" https_proxy="${PROXY}" HTTP_PROXY="${PROXY}" HTTPS_PROXY="${PROXY}" "$@"
	else
		info_note "[proxy] perfer proxy, but not set"
		http_proxy='' https_proxy='' HTTP_PROXY='' HTTPS_PROXY='' "$@"
	fi
}
function deny_proxy() {
	# info_note "[proxy] deny proxy"
	http_proxy='' https_proxy='' HTTP_PROXY='' HTTPS_PROXY='' "$@"
}

function buildah_run_perfer_proxy() {
	perfer_proxy buildah run "$@"
}

function buildah_run_deny_proxy() {
	deny_proxy buildah run "$@"
}

_IS_CHINA=""
_IS_CHINA_CACHE="${SYSTEM_COMMON_CACHE}/is_china.txt"
if [[ -e ${_IS_CHINA_CACHE} ]]; then
	_IS_CHINA=$(<"${_IS_CHINA_CACHE}")
fi
function is_china() {
	if [[ ${_IS_CHINA} == yes ]]; then
		return 0
	elif [[ ${_IS_CHINA} == no ]]; then
		return 1
	fi
	if is_ci; then
		return 1
	fi

	info_note "checking if in China..."

	local PING_OVERSEA PING_CHINA
	PING_OVERSEA=$(ping www.google.com -c 4 -W 1 | tail -n1 | cut -d "/" -s -f5 | cut -d "." -f1 || echo 9999)
	PING_CHINA=$(ping www.dnspod.cn -c 4 -W 1 | tail -n1 | cut -d "/" -s -f5 | cut -d "." -f1 || echo 9999)

	if ((PING_OVERSEA > PING_CHINA)); then
		info_note "  * found Oversea: ping ${PING_OVERSEA}ms, china ping ${PING_CHINA}ms"
		_IS_CHINA=yes
	else
		info_note "  * found China: ping ${PING_CHINA}ms, oversea ping ${PING_OVERSEA}ms"
		_IS_CHINA=no
	fi
	printf "%s" "${_IS_CHINA}" >"${_IS_CHINA_CACHE}"

	[[ ${_IS_CHINA} == yes ]]
}

if is_ci; then
	function SHELL_USE_PROXY() {
		echo "PROXY="
	}
	function perfer_proxy() {
		"$@"
	}
	function deny_proxy() {
		"$@"
	}
fi

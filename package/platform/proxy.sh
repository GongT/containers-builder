#!/usr/bin/env bash

if [[ -z ${PROXY-} ]]; then
	PROXY=${https_proxy-}
fi
if [[ -n ${PROXY} && ${PROXY} != http://* && ${PROXY} != https://* ]]; then
	PROXY="http://${PROXY}"
fi
declare -xr PROXY

info_note "using PROXY="

function SHELL_USE_PROXY() {
	if [[ ${PROXY+found} == found ]]; then
		echo "PROXY=${PROXY}"
	else
		echo "PROXY="
	fi
	# shellcheck disable=SC2016
	echo '
if [[ -n "$PROXY" ]]; then
	echo "using proxy: ${PROXY}..." >&2
	export http_proxy="$PROXY"
	export https_proxy="$PROXY"
fi
'
}

function perfer_proxy() {
	if [[ ${PROXY+found} == "found" ]]; then
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

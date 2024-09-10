#!/usr/bin/env bash

info_note "using HTTP_PROXY=${HTTP_PROXY:-*not set*}"
info_note "using PROXY=${PROXY:-*not set*}"

function SHELL_USE_PROXY() {
	if [[ ${PROXY+found} == found ]]; then
		echo "PROXY=${PROXY}"
	else
		echo "PROXY="
	fi
	# shellcheck disable=SC2016
	echo '
if [ -n "$PROXY" ]; then
	echo "using proxy: ${PROXY}..." >&2
	export http_proxy="$PROXY"
	export https_proxy="$PROXY"
fi
'
}

function remove_proxy_schema() {
	if [[ ${PROXY+found} != "found" ]]; then
		return
	fi
	if [[ ${PROXY} != *'://'* ]]; then
		return
	fi
	export PROXY="${PROXY//*:///}"
}
function add_proxy_http_schema() {
	if [[ ${PROXY+found} != "found" ]]; then
		return
	fi
	if [[ ${PROXY} == *'://'* ]]; then
		return
	fi
	export PROXY="http://${PROXY}"
}

function perfer_proxy() {
	if [[ $1 == --no-schema ]]; then
		remove_proxy_schema
		shift
	else
		add_proxy_http_schema
		if [[ $1 == --schema ]]; then
			shift
		fi
	fi
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

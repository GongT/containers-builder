#!/usr/bin/env bash

info_note "using HTTP_PROXY=${HTTP_PROXY:-*not set*}"
info_note "using PROXY=${PROXY:-*not set*}"

function run_without_proxy() {
	info_note "[http_proxy] run command $* without proxy"
	HTTP_PROXY= HTTPS_PROXY= ALL_PROXY= http_proxy= https_proxy= all_proxy= "$@"
}

function run_with_proxy() {
	if [[ ! ${HTTP_PROXY:-} ]] && [[ ${PROXY:-} ]]; then
		info_note "[http_proxy] run command $* with force proxy"
		HTTP_PROXY="$PROXY" HTTPS_PROXY="$PROXY" ALL_PROXY="$PROXY" http_proxy="$PROXY" https_proxy="$PROXY" all_proxy="$PROXY" "$@"
	else
		info_note "[http_proxy] run command $* with force proxy, but no server defined"
		"$@"
	fi
}

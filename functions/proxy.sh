#!/usr/bin/env bash

info_note "http_proxy=${http_proxy:-*not set*}"
info_note "PROXY=${http_proxy:-*not set*}"

function run_without_proxy() {
	local HTTP_PROXY= HTTPS_PROXY= ALL_PROXY= http_proxy= https_proxy= all_proxy=
	"$@"
}

function run_with_proxy() {
	if [[ "${HTTP_PROXY+found}" != found ]] && [[ -n "${PROXY:-}" ]]; then
		local HTTP_PROXY="$PROXY" HTTPS_PROXY="$PROXY" ALL_PROXY="$PROXY" http_proxy="$PROXY" https_proxy="$PROXY" all_proxy="$PROXY"
	fi
	"$@"
}

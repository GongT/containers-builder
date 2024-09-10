#!/usr/bin/env bash

function split_url_user_pass_host_port() {
	local LINE="$1" CRED
	CRED="${LINE%@*}"
	DOMAIN="${LINE##*@}"

	USERNAME="${CRED%%:*}"
	PASSWORD="${CRED#*:}"

	HOST_NAME="${DOMAIN%%:*}"
	PORT_NUMBER="${DOMAIN#*:}"
}

function split_url_domain_path() {
	local LINE="$1"

	DOMAIN="${LINE%%/*}"
	PATHNAME="${LINE#*/}"
	if [[ $PATHNAME ]]; then
		PATHNAME="/$PATHNAME"
	fi
}

function emit_bash_arguments() {
	printf " %q" "$@"
}

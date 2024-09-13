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
	if [[ -n ${PATHNAME} ]]; then
		PATHNAME="/${PATHNAME}"
	fi
}

function emit_bash_arguments() {
	if [[ $# -eq 0 ]]; then
		return
	fi
	printf " %q" "$@"
}

function escape_argument() {
	printf '%s' "$1" | jq --raw-input -s '.'
}
function printf_command_direction() {
	local PREFIX=$1
	shift

	printf '%s' "${PREFIX}"
	escape_argument_list_sameline "$@"
	printf '\n'
}
function escape_argument_list_sameline() {
	local ARG ARGS=("$@")

	local __LAST=${ARGS[-1]}
	unset "ARGS[-1]"

	for ARG in "${ARGS[@]}"; do
		printf '%s ' "$(escape_argument "$ARG")"
	done
	printf '%s' "$(escape_argument "$__LAST")"
}

function escape_argument_list_continue() {
	local ARG ARGS=("$@")

	local __LAST=${ARGS[-1]}
	unset "ARGS[-1]"

	for ARG in "${ARGS[@]}"; do
		printf '\t%s \\\n' "$(escape_argument "$ARG")"
	done
	printf '\t%s' "$(escape_argument "$__LAST")"
}

function split_exec_command_prefix() {
	local __COMMAND=$1 VAR_PREFIX=$2 VAR_COMMAND=$3
	local __PREFIX=''

	while [[ ${__COMMAND} =~ ^[-@:+!] ]]; do
		__PREFIX+=${__COMMAND:0:1}
		__COMMAND=${__COMMAND:1}
	done

	printf -v "$VAR_PREFIX" '%s' "$__PREFIX"
	printf -v "$VAR_COMMAND" '%s' "$__COMMAND"
}

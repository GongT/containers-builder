#!/usr/bin/env bash

function do_attach() {
	if [[ $# -eq 0 ]]; then
		die "missing arguments"
	fi

	TARGET="$1" CMD=""
	shift
	if [[ $# -gt 0 ]]; then
		CMD="$1"
		shift
	else
		set -- --login -i
	fi

	local -a CONTAINER_IDNAMES
	mapfile -t CONTAINER_IDNAMES < <(podman container list --format '{{.ID}} {{.Names}}' | grep -F "${TARGET}")
	if [[ ${#CONTAINER_IDNAMES[@]} -gt 1 ]]; then
		printf "  - %s\n" "${CONTAINER_IDNAMES[@]}"
		die "can not filter unique container by ${TARGET}"
	fi
	if [[ ${#CONTAINER_IDNAMES[@]} -eq 0 ]]; then
		die "no container match ${TARGET}"
	fi

	read -r CID NAME < <(echo "${CONTAINER_IDNAMES[0]}")
	if [[ -z ${CMD} ]]; then
		ROOT=$(podman mount "${CID}" || true)
		if [[ -n ${ROOT} && -e "${ROOT}/usr/bin/bash" ]]; then
			CMD='/usr/bin/bash'
		else
			CMD='/bin/sh'
		fi
	fi
	echo -e " + podman exec -it \e[38;5;11m${NAME}\e[0m ${CMD} $*" >&2
	_PS1=$(printf '\[\][\[\e[38;5;14m\]%s\[\e[0m\]:\W]# \[\]' "${NAME#managed_}")
	exec podman exec "--env=PS1=$_PS1" -it "${CID}" "${CMD}" "$@"
}

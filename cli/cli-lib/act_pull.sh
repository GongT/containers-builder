#!/usr/bin/env bash

function get_image_name_from_service_file() {
	grep 'IMAGE_NAME=' "$1" -R | sed -E 's/^.*IMAGE_NAME=//g' | sort | uniq
}

do_pull_all() {
	set -Eeuo pipefail

	cd /usr/lib/systemd/system
	local -a IMAGE_LIST
	if [[ $# -eq 0 ]]; then
		mapfile -t IMAGE_LIST < <(get_image_name_from_service_file .)
	else
		for I; do
			SRV=$(get_service_file "$I") || die "no such service: $I"
			IMAGE_LIST+=("$(get_image_name_from_service_file "$SRV")")
		done
	fi

	go_home

	trap 'echo "" ; exit 0' INT
	unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
	export SKIP_REMOVE=yes

	FAILED=()
	for IMAGE_NAME in "${IMAGE_LIST[@]}"; do
		echo -e "\e[7;38;5;3m$IMAGE_NAME\e[0m" >&2
		if bash ../tools/pull-image.sh "registry.gongt.me/$IMAGE_NAME" always; then
			echo -e "\e[38;5;10mDone!\e[0m" >&2
		else
			echo -e "\e[38;5;9mFailed!\e[0m" >&2
			FAILED+=("$IMAGE_NAME")
		fi
	done

	if [[ ${#FAILED[@]} -gt 0 ]]; then
		echo -e "\e[38;5;9mFailed: ${FAILED[*]}\e[0m" >&2
	fi
}

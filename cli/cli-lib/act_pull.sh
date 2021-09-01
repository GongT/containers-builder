#!/usr/bin/env bash

pull_all() {
	echo "$*"
	local ARG IMAGES=()
	for ARG in "${@}"; do
		if [[ $ARG == '--force' ]]; then
			export FORCE_PULL=yes
		else
			IMAGES+=("${ARG}")
		fi
	done
	set -- "${IMAGES[@]}"
	go_home
	source _scripts_/pull_all_images.sh "$@"
}

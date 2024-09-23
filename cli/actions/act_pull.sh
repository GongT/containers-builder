#!/usr/bin/env bash
do_pull() {
	local FORCE_PULL=no
	LIST=()
	for I; do
		if [[ $I == "-f" ]]; then
			FORCE_PULL=yes
		else
			LIST+=("$I")
		fi
	done

	cd "${SYSTEM_UNITS_DIR}"
	local -a SERVICE_NAMES=()
	if [[ ${#LIST[@]} -eq 0 ]]; then
		expand_service_file | mapfile -t SERVICE_NAMES
	else
		for I in "${LIST[@]}"; do
			local SRVN
			expand_service_file "$I" | while read -r SRVN; do
				SERVICE_NAMES+=("$SRVN")
			done
		done
	fi

	local UNIQ
	UNIQ=$(printf '%s\n' "${SERVICE_NAMES[@]}" | sort | uniq)
	printf '%s' "$UNIQ" | mapfile -t SERVICE_NAMES

	go_home

	trap 'echo "" ; exit 0' INT
	unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
	export SKIP_REMOVE=yes

	SUCCESS=()
	FAILED=()
	for SRV_FILE in "${SERVICE_NAMES[@]}"; do
		info "\e[7;38;5;3m  $SRV_FILE  \e[0m"

		TARGET_SCRIPT_DIR=$(systemctl cat "${SRV_FILE}" | filter_service_file_comment SCRIPTS_DIR)
		if [[ -z ${TARGET_SCRIPT_DIR} ]]; then
			info_error "missing SCRIPTS_DIR"
			continue
		fi

		if env -i "FORCE_PULL=${FORCE_PULL}" "SKIP_REMOVE=yes" "${TARGET_SCRIPT_DIR}/pull-image" always; then
			info_success "\e[38;5;10mDone!\e[0m"
			SUCCESS+=("$SRV_FILE")
		else
			info_error "\e[38;5;9mFailed!\e[0m"
			FAILED+=("$SRV_FILE")
		fi
	done

	if [[ ${#FAILED[@]} -gt 0 ]]; then
		info_error "\e[38;5;9mFailed: ${FAILED[*]}\e[0m"
	fi

	if [[ ${#SUCCESS[@]} -gt 0 ]]; then
		info_note "removing unused images:"
		podman image list --noheading \
			| grep --fixed-strings '<none>' \
			| awk '{print $3}' \
			| xargs --no-run-if-empty -t podman image rm || true
	fi
}

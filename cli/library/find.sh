find_one_container_by_hint() {
	local CONTAINER_HINT="$1" FILTER="${2:-(running|activating)}" SERVICE_FULL_NAMES
	SERVICE_FULL_NAMES=$(systemctl list-units --all "*${CONTAINER_HINT}*.pod@.service" "*${CONTAINER_HINT}*.pod.service" --no-pager --no-legend | sed 's/●//g' | grep -E "${FILTER}" | awk '{print $1}' | head -n1)
	if [[ -z ${SERVICE_FULL_NAMES} ]]; then
		info_note "$(x systemctl list-units --all "*${CONTAINER_HINT}*.pod@.service" "*${CONTAINER_HINT}*.pod.service" --no-pager --no-legend)"
		info_note "FILTER=${FILTER}"
		return 1
	fi
	if [[ ${SERVICE_FULL_NAMES} == *"\n"* ]]; then
		info_note "$(x systemctl list-units --all "*${CONTAINER_HINT}*.pod@.service" "*${CONTAINER_HINT}*.pod.service" --no-pager --no-legend)"
		info_note "FILTER=${FILTER}"
		info_warn "matching multiple service by ${CONTAINER_HINT}"
		return 1
	fi

	get_container_by_service "${SERVICE_FULL_NAMES}"
}

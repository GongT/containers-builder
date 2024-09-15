function apply_container_healthcheck() {
	declare -r ANNO_MY_HEALTHCHECK="healthcheck"
	DEF=$(get_image_annotation "${ANNO_MY_HEALTHCHECK}" 2>/dev/null)
	declare -a HC_ARGS=()
	json_array_get_back HC_ARGS "${DEF}"
	if [[ ${#HC_ARGS[@]} -gt 0 ]]; then
		info_log "load healthcheck arguments."
		push_engine_param "${HC_ARGS[@]}"
	elif [[ ${INPUT_CMDLINE[*]} == "--healthcheck" ]]; then
		info_log "commandline healthcheck."
	else
		info_log "image not using healthcheck."
	fi
	unset DEF HC_ARGS
}

function is_image_has_healthcheck() {
	[[ "${ENGINE_PARAMS[*]} ${COMMAND_LINE[*]}" == *"--healthcheck="* ]]
}

function apply_container_healthcheck() {
	declare -r ANNO_MY_HEALTHCHECK="healthcheck"
	DEF=$(current_image_find_annotation "${ANNO_MY_HEALTHCHECK}")
	info_note "健康检查定义: ${DEF}"
	declare -a HC_ARGS=()
	json_array_get_back HC_ARGS "${DEF}"
	if [[ ${#HC_ARGS[@]} -gt 0 ]]; then
		info_log "载入健康检查参数"
		push_engine_param "${HC_ARGS[@]}"
	elif [[ ${INPUT_CMDLINE[*]} == "--healthcheck" ]]; then
		info_log "使用命令行健康检查."
	else
		info_log "镜像未使用健康检查"
	fi
	unset DEF HC_ARGS
}

function is_image_has_healthcheck() {
	[[ "${ENGINE_PARAMS[*]} ${COMMAND_LINE[*]}" == *"--healthcheck="* ]]
}

declare -r ANNO_MY_HEALTHCHECK="healthcheck"
function is_image_has_healthcheck() {
	[[ "${ARGS[*]} ${INPUT_ARGUMENTS[*]}" == *"--healthcheck="* ]]
}

DEF=$(get_image_annotation "${ANNO_MY_HEALTHCHECK}" 2>/dev/null)
json_array_get_back HC_ARGS "${DEF}"
if [[ ${#HC_ARGS[@]} -gt 0 ]]; then
	debug "load healthcheck arguments."
	add_run_argument "${HC_ARGS[@]}"
elif [[ ${INPUT_ARGUMENTS[*]} == "--healthcheck" ]]; then
	debug "commandline healthcheck."
else
	debug "image not using healthcheck."
fi
unset DEF HC_ARGS

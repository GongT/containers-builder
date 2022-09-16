function _env_passing_file_path() {
	echo "$CONTAINERS_DATA_PATH/save_environments/$PROJECT_NAME.$1.txt"
}

function controller_environment_variable() {
	local KV K V

	for KV; do
		K="${KV%%=*}"
		V="${KV#*=}"
		_S_CONTROL_ENVS["$K"]="$V"
	done
}
function _commit_controller_environment() {
	local F="$(_env_passing_file_path control)"

	local VAR_NAME OUTPUT=''
	if [[ ${#_S_CONTROL_ENVS[@]} -eq 0 ]]; then
		return
	fi

	for VAR_NAME in "${!_S_CONTROL_ENVS[@]}"; do
		OUTPUT+="$VAR_NAME=${_S_CONTROL_ENVS[$VAR_NAME]}"
		OUTPUT+=$'\n'
	done

	OUTPUT=$(echo "$OUTPUT" | sed -E 's#\s+$##g')

	write_file "$F" "$OUTPUT"
	chmod 0600 "$F"

	echo "EnvironmentFile=$F"
}

function unit_podman_safe_environment() {
	environment_variable "$@"
}

function environment_variable() {
	local KV K V

	for KV; do
		K="${KV%%=*}"
		V="${KV#*=}"
		_S_ENVIRONMENTS["$K"]="$V"
	done
}

function safe_environment() {
	die "removed function safe_environment, use environment_variable"
}

function _commit_environment() {
	local F="$(_env_passing_file_path container)"

	local OUTPUT='' VAR_NAME
	echo -e "\e[2mPasthrough Environments:\e[0m" >&2
	if [[ ${#_S_ENVIRONMENTS[@]} -eq 0 ]]; then
		echo -e "\e[2m    empty\e[0m" >&2
		return
	fi

	for VAR_NAME in "${!_S_ENVIRONMENTS[@]}"; do
		OUTPUT+="$VAR_NAME=${_S_ENVIRONMENTS[$VAR_NAME]}"
		OUTPUT+=$'\n'
		echo -e "\e[2m    - $VAR_NAME -> ${_S_ENVIRONMENTS[$VAR_NAME]}\e[0m" >&2
	done

	OUTPUT=$(echo "$OUTPUT" | sed -E 's#\s+$##g')

	write_file "$F" "$OUTPUT"
	chmod 0600 "$F"

	unit_podman_arguments "--env-file=$F"
}

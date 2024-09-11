function _env_passing_file_path() {
	echo "${CONTAINERS_DATA_PATH}/save_environments/${_S_CURRENT_UNIT_NAME}.$1.txt"
}

function controller_environment_variable() {
	local KV K V

	for KV; do
		K="${KV%%=*}"
		V="${KV#*=}"
		_S_CONTROL_ENVS["${K}"]="${V}"
	done
}

function unit_podman_safe_environment() {
	environment_variable "$@"
}

function environment_variable() {
	local KV K V

	for KV; do
		K="${KV%%=*}"
		V="${KV#*=}"
		_S_ENVIRONMENTS["${K}"]="${V}"
	done
}

function safe_environment() {
	die "removed function safe_environment, use environment_variable"
}

function __commit_environment() {
	local F
	F="$(_env_passing_file_path container)"

	local OUTPUT='' VAR_NAME

	if is_installing; then
		info_note "Pasthrough Environments:"
		if [[ ${#_S_ENVIRONMENTS[@]} -eq 0 ]]; then
			info_note "    empty"
			return
		fi
	fi

	for VAR_NAME in "${!_S_ENVIRONMENTS[@]}"; do
		OUTPUT+="${VAR_NAME}=${_S_ENVIRONMENTS[${VAR_NAME}]}"
		OUTPUT+=$'\n'
		is_installing && info_note "    - ${VAR_NAME} -> ${_S_ENVIRONMENTS[${VAR_NAME}]}"
	done

	OUTPUT=$(echo "${OUTPUT}" | sed -E 's#\s+$##g')

	write_file --mode 0600 "${F}" "${OUTPUT}"

	unit_podman_arguments "--env-file=${F}"

	local VAR_NAME OUTPUT=''
	if [[ ${#_S_CONTROL_ENVS[@]} -eq 0 ]]; then
		return
	fi

	# shellcheck disable=SC2155
	local F="$(_env_passing_file_path control)"

	for VAR_NAME in "${!_S_CONTROL_ENVS[@]}"; do
		OUTPUT+=$(printf '%s=%q\n' "${VAR_NAME}" "${_S_CONTROL_ENVS[${VAR_NAME}]}")
	done

	OUTPUT=$(echo "${OUTPUT}" | sed -E 's#\s+$##g')

	write_file --mode 0600 "${F}" "${OUTPUT}"

	unit_body "EnvironmentFile=${F}"
}
register_unit_emit __commit_environment

declare -A _S_CONTROL_ENVS
__reset_env_container() {
	_S_CONTROL_ENVS=()
	_S_CONTROL_ENVS[REGISTRY_AUTH_FILE]="/etc/containers/auth.json"
}
register_unit_reset __reset_env_container

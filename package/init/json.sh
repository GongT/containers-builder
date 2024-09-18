declare -r JQ_ARGS=(--exit-status --compact-output --monochrome-output --raw-output)
function filtered_jq() {
	local INPUT
	INPUT=$(jq "${JQ_ARGS[@]}" "$@")
	if [[ ${INPUT} == "null" ]]; then
		echo "failed query $1" >&2
		return 1
	fi
	echo "${INPUT}"
}
function parse_json() {
	local -r INPUT=$1 QUERY="\$ARGS.named.INPUT | ${2}"
	jq "${JQ_ARGS[@]}" --null-input "${QUERY}" --argjson INPUT "${INPUT}" "${@:3}"
}
function json_map() {
	local -nr VARREF=$1
	if ! variable_is_map "$1"; then
		info_error "variable is not map: $(declare -p "${VARNAME}" 2>&1)"
		return 1
	fi
	local ARGS=()
	for KEY in "${!VARREF[@]}"; do
		ARGS+=("--arg" "${KEY}" "${VARREF[${KEY}]}")
	done
	jq "${JQ_ARGS[@]}" --null-input --slurp '$ARGS.named' "${ARGS[@]}"
}

function json_map_get_back() {
	local -r VARNAME="$1" JSON="$2"
	if ! variable_is_map "${VARNAME}"; then
		info_error "variable is not map: $(declare -p "${VARNAME}" 2>&1)"
		return 1
	fi

	local CODE
	CODE=$(jq "${JQ_ARGS[@]}" --null-input '$ARGS.named.DATA | to_entries[] | "  [" + (.key|@sh) + "]=" + (.value|@sh)' --argjson DATA "$JSON")
	if [[ ${CODE} == null ]]; then
		return
	fi
	eval "${VARNAME}=(${CODE})"
}

function json_array() {
	if [[ $# -eq 0 ]]; then
		echo '[]'
		return
	fi
	jq "${JQ_ARGS[@]}" --null-input --slurp '$ARGS.positional' --args -- "$@"
}

function json_array_get_back() {
	local -r _VARNAME="$1" JSON="$2"

	if ! variable_is_array "${_VARNAME}"; then
		info_error "variable is not array: $(declare -p "${_VARNAME}" 2>&1)"
		callstack 0
		return 1
	fi

	local -i SIZE i
	local CODE
	CODE=$(jq "${JQ_ARGS[@]}" --null-input '$ARGS.named.JSON | @sh' --argjson JSON "$JSON")
	if [[ ${CODE} == null ]]; then
		eval "${_VARNAME}=()"
		return
	fi
	eval "${_VARNAME}=(${CODE})"
}

if [[ $# -ne 2 ]]; then
	echo "Usage: $0 <source-file> <template.yaml>"
	exit 1
fi

declare -xr _BUILDSCRIPT_RUN_STEP_=none

CWD=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
SOURCE_FILE=$(realpath "$1")
TEMPLATE=$(realpath "$2")

# shellcheck source=/dev/null
source "${SOURCE_FILE}"

# shellcheck source=package/include-build.sh disable=SC2312
source "${CWD}/package/include-build.sh"

if [[ -z ${STEPS_DEFINE+f} ]] || [[ ${#STEPS_DEFINE[@]} -eq 0 ]]; then
	die "no build steps found"
fi

function parse_file_sections() {
	declare -g FILE_PREFIX='' FILE_SUFFIX='' STEP_CONTENT='' STEP_INDENT=''
	local STATE=prefix LINE

	while IFS='' read -r LINE; do
		if [[ ${STATE} == prefix ]]; then
			if [[ ${LINE} == *'### BUILD_SCTION START ###'* ]]; then
				STATE=content-first
			else
				printf -v FILE_PREFIX '%s%s\n' "${FILE_PREFIX}" "${LINE}"
			fi
		elif [[ ${STATE} == content-first ]]; then
			STATE=content
			STEP_INDENT="${LINE/[^[:space:]]*/}"

			printf -v STEP_CONTENT '%s%s\n' "${STEP_CONTENT}" "${LINE:${#STEP_INDENT}}"
		elif [[ ${STATE} == content ]]; then
			if [[ ${LINE} == *'### BUILD_SCTION END ###'* ]]; then
				STATE=suffix
			else
				printf -v STEP_CONTENT '%s%s\n' "${STEP_CONTENT}" "${LINE:${#STEP_INDENT}}"
			fi
		elif [[ ${STATE} == suffix ]]; then
			printf -v FILE_SUFFIX '%s%s\n' "${FILE_SUFFIX}" "${LINE}"
		fi
	done <"${TEMPLATE}"
}
parse_file_sections

function create_section() {
	python3 "${COMMON_LIB_ROOT}/staff/build-steps/generate-section.py" "${STEP_CONTENT}" "${STEPDEF[title]}" "${STEPDEF[name]}" "${STEPDEF[index]}" \
		| sed -u "s/^/${STEP_INDENT}/"
}

info_success "collected ${#STEPS_DEFINE[@]} steps"
{
	echo "${FILE_PREFIX}"
	declare -A STEPDEF=()
	for JSON in "${STEPS_DEFINE[@]}"; do
		json_map_get_back "STEPDEF" "${JSON}"

		create_section
	done
	echo "${FILE_SUFFIX}"
}

if [[ $# -ne 3 ]]; then
	echo "Usage: $0 <source-file> <template.yaml> <output.yaml>"
	exit 1
fi

ENV_VARS=()
for var in $(compgen -e); do
	if [[ $(type -t "$var") == "function" ]]; then
		continue
	fi
	ENV_VARS+=("$var")
done

declare -xr _BUILDSCRIPT_RUN_STEP_=none

LIBDIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
SOURCE_FILE=$(realpath "$1")
TEMPLATE=$(realpath "$2")
OUTPUT_FILE=$(realpath -m "$3")
for arg; do shift; done

SOURCE_FILE_REL=$(realpath "--relative-to=$(pwd)" "${SOURCE_FILE}")

CURRENT_FILE="${SOURCE_FILE}"
# shellcheck source=/dev/null
source "${SOURCE_FILE}"

# shellcheck source=package/include-build.sh disable=SC2312
source "${LIBDIR}/package/include-build.sh"

if [[ -z ${STEPS_DEFINE+f} ]] || [[ ${#STEPS_DEFINE[@]} -eq 0 ]]; then
	die "no build steps found"
fi

function parse_file_sections() {
	declare -g FILE_PREFIX='' FILE_MIDDLE='' FILE_SUFFIX='' STEP_CONTENT='' STEP_INDENT=''
	local STATE=prefix LINE

	while IFS='' read -r LINE; do
		if [[ ${STATE} == prefix ]]; then
			printf -v FILE_PREFIX '%s%s\n' "${FILE_PREFIX}" "${LINE}"
			if [[ ${LINE} == 'env:' ]]; then
				STATE=middle
			fi
			if [[ ${LINE} == *'### BUILD_SCTION START ###'* ]]; then
				die "missing env: section"
			fi
		elif [[ ${STATE} == middle ]]; then
			if [[ ${LINE} == *'### BUILD_SCTION START ###'* ]]; then
				STATE=content-first
			else
				printf -v FILE_MIDDLE '%s%s\n' "${FILE_MIDDLE}" "${LINE}"
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
	python3 "${COMMON_LIB_ROOT}/staff/build-steps/generate-section.py" "${STEP_CONTENT}" "${STEPDEF[index]}" "${STEPDEF[title]}" \
		"_BUILDSCRIPT_RUN_STEP_=${STEPDEF[name]}:${STEPDEF[index]}" \
		| sed -u "s/^/${STEP_INDENT}/"
}

DIR=$(dirname "${CURRENT_FILE}")
REL_DIR=$(realpath "--relative-to=$MONO_ROOT_DIR" "${DIR}")

info_success "collected ${#STEPS_DEFINE[@]} steps"
OUTPUT=$(
	echo "${FILE_PREFIX}"
	printf "  SOURCE_FILE: %s\n" "${SOURCE_FILE_REL}"
	printf "  PROJECT_DIR: %s\n" "${REL_DIR}"
	echo "${FILE_MIDDLE}"
	declare -A STEPDEF=()
	for JSON in "${STEPS_DEFINE[@]}"; do
		json_map_get_back "STEPDEF" "${JSON}"

		create_section
	done
	echo "${FILE_SUFFIX}"
)

for var in "${ENV_VARS[@]}"; do
	OUTPUT=${OUTPUT//"{{$var}}"/${!var}}
done

write_file --mode 0644 "${OUTPUT_FILE}" "${OUTPUT}"

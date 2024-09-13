LABEL_TO_REMOVE=(
	"org.opencontainers.image.licenses"
	"org.opencontainers.image.title"
	"org.opencontainers.image.url"
	"org.opencontainers.image.version"
	"systemd.service.invocation_id"
)

function __handle_default_labels() {
	add_build_config "--label=org.opencontainers.image.authors=${AUTHOR}"
	add_build_config "--label=org.opencontainers.image.created=$(date -Iseconds)"
	add_build_config "--label=org.opencontainers.image.name=${PROJECT_NAME}"

	add_build_config "--label=org.opencontainers.image.description-"
	add_build_config "--label=org.opencontainers.image.vendor-"
	add_build_config "--label=org.opencontainers.image.version-"
	add_build_config "--label=name-"
	add_build_config "--label=license-"
	add_build_config "--label=vendor-"
	add_build_config "--label=version-"

	local licence='' title=''
	if [[ -e "${CURRENT_DIR}/README.md" ]]; then
		head -n1 "${CURRENT_DIR}/README.md" | sed 's/^#*\s*//g' | read -r title
	fi
	if [[ -n ${MONO_ROOT_DIR-} ]]; then
		local licence_file="${MONO_ROOT_DIR-}/LICENSE"
		if [[ -f ${licence_file} ]]; then
			cat "${licence_file}" | read -r licence
		fi
	fi
	if [[ -n ${licence} ]]; then
		add_build_config "--label=org.opencontainers.image.license=${licence}"
	else
		add_build_config "--label=org.opencontainers.image.license-"
	fi
	if [[ -n ${title} ]]; then
		add_build_config "--label=org.opencontainers.image.title=${title}"
	else
		add_build_config "--label=org.opencontainers.image.title-"
	fi

	if [[ -n ${GITHUB_SERVER_URL-} ]] && [[ -n ${GITHUB_REPOSITORY-} ]]; then
		add_build_config "--label=org.opencontainers.image.source=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}"
		add_build_config "--label=org.opencontainers.image.url=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}"
	else
		add_build_config "--label=org.opencontainers.image.source-"
		add_build_config "--label=org.opencontainers.image.url-"
	fi
	if [[ -n ${GITHUB_SHA-} ]]; then
		add_build_config "--label=org.opencontainers.image.revision=${GITHUB_SHA}"
	else
		add_build_config "--label=org.opencontainers.image.revision-"
	fi
	if [[ -n ${GITHUB_SERVER_URL-} ]] && [[ -n ${GITHUB_REPOSITORY-} ]]; then
		add_build_config "--label=org.opencontainers.image.source=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}"
	else
		add_build_config "--label=org.opencontainers.image.source-"
	fi
}

register_argument_config __handle_default_labels

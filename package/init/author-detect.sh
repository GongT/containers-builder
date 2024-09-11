function detect_author() {
	if is_ci; then
		AUTHOR="${GITHUB_REPOSITORY%/*}"
	else
		AUTHOR="${USER:-nobody}/$(hostname)"
	fi
	declare -g AUTHOR
}

if [[ -z ${AUTHOR-} ]]; then
	detect_author
fi

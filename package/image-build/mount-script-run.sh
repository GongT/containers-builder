function buildah_run_shell_script() {
	local CONTAINER SCRIPT_FILE SH="bash"
	if [[ $# -lt 2 ]]; then
		die "buildah_run_shell_script: missing arguments, at least 2, got $#"
	fi

	local ARGS=("$@")
	SCRIPT_FILE=${ARGS[-1]}
	CONTAINER=${ARGS[-2]}
	ARGS=("${ARGS[@]:0:$(($# - 2))}")

	SCRIPT_FILE=$(realpath --no-symlinks --canonicalize-existing "${SCRIPT_FILE}")
	if [[ -x $SCRIPT_FILE ]]; then
		SH=
	else
		HEAD_LINE="$(head -1 "${SCRIPT_FILE}")"
		if [[ $HEAD_LINE == '#!'* ]]; then
			SH=${HEAD_LINE:2}
		fi
	fi

	if [[ -z ${WHO_AM_I-} ]]; then
		info_warn "run script ${SCRIPT_FILE} without a title (WHO_AM_I)"
		ARGS+=("--env=WHO_AM_I=${SCRIPT_FILE}")
	else
		ARGS+=("--env=WHO_AM_I=${WHO_AM_I}")
	fi

	# shellcheck disable=SC2086
	indent_stream buildah run "${ARGS[@]}" "--volume=${SCRIPT_FILE}:/tmp/_script:ro" "$1" ${SH} /tmp/_script \
	unset WHO_AM_I
}

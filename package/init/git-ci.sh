declare -i INSIDE_GROUP=

function control_ci() {
	local -r ACTION="$1"
	shift
	# info_log "[CI] Action=$ACTION, Args=$*" >&2
	case "${ACTION}" in
	set-env)
		local NAME=$1 VALUE=$2
		export "${NAME}=${VALUE}"
		if ! is_ci; then
			return
		fi

		{
			echo "${NAME}<<EOF"
			echo "${VALUE}"
			echo 'EOF'
		} >>"${GITHUB_ENV}"
		;;
	error | notice | warning)
		local TITLE=$1 MESSAGE=$2
		if is_ci; then
			echo "::${ACTION} title=${TITLE}::${MESSAGE}" >&2
		elif [[ ${ACTION} == 'error' ]]; then
			info_error "[CI EVENT: ${TITLE}]"
		elif [[ ${ACTION} == 'warning' ]]; then
			info_warn "[CI EVENT: ${TITLE}]"
		elif [[ ${ACTION} == 'notice' ]]; then
			info "[CI EVENT: ${TITLE}]"
		fi
		;;
	summary)
		if [[ -z ${GITHUB_STEP_SUMMARY-} ]]; then
			if is_root; then
				GITHUB_STEP_SUMMARY="${CURRENT_DIR}/.BUILD.md"
			else
				GITHUB_STEP_SUMMARY=$(create_temp_file build.md)
			fi
			echo >"${GITHUB_STEP_SUMMARY}"
		fi
		echo "$1" >>"${GITHUB_STEP_SUMMARY}"
		;;
	group)
		INSIDE_GROUP=$((INSIDE_GROUP + 1))
		if [[ ${INSIDE_GROUP} -gt 5 ]]; then
			die "too many group level"
		fi
		if [[ ${INSIDE_GROUP} -eq 1 ]] && is_ci; then
			save_indent
			echo "::group::$*" >&2
		else
			info_bright "[Start Group] $*"
			indent
		fi
		;;
	groupEnd)
		if [[ ${INSIDE_GROUP} -eq 0 ]]; then
			info_error "mismatch group start / end"
			return
		fi
		INSIDE_GROUP=$((INSIDE_GROUP - 1))
		if [[ ${INSIDE_GROUP} -eq 0 ]] && is_ci; then
			restore_indent
			echo "::endgroup::" >&2
		else
			dedent
			info_note "[End Group]"
		fi
		;;
	*)
		die "[CI] not support action: ${ACTION}"
		;;
	esac
}

function get_current_commit_message_first_line() {
	if ! is_ci; then
		echo "not running in CI"
		return 0
	fi
	x git log -n 1 --format=%s | head -n1 || true
}

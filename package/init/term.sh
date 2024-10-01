function get_cursor_line() {
	is_tty 2 || return 1
	local RESP _ COL
	declare -gi CURSOR_LINE=0

	IFS='[;' read -t 1 -r -s -d 'R' -p $'\e[6n' _ CURSOR_LINE COL
}

function save_cursor_position() {
	is_tty 2 || return 0
	printf '\e[s' >&2
}
function restore_cursor_position() {
	is_tty 2 || return 0
	if ! get_cursor_line; then
		return 0
	fi
	local -i SAVED=${CURSOR_LINE} CLEAR=${1-1}
	printf '\e[u' >&2
	if get_cursor_line && [[ $CURSOR_LINE -gt 1 ]]; then
		if [[ ${CLEAR} -ne 0 ]]; then
			printf '\e[J' >&2
		fi
	else
		printf '\e[%d;1H' ${SAVED} ${SAVED} >&2
		if [[ ${CLEAR} -ne 0 ]]; then
			printf '\e[K' >&2
		fi
	fi
}
function soft_clear() {
	local -i LINES=10
	if ! LINES=$(tput lines); then
		LINES=10
	fi
	for ((i = 1; i < LINES; i++)); do
		printf '\n'
	done
}

function no_scroll_logging() {
	local TITLE="$1"
	shift

	if is_ci; then
		control_ci group "${TITLE}"
		"$@"
		control_ci groupEnd
	fi

	local TMP_OUT
	TMP_OUT=$(create_temp_file "screen.output.txt")
	save_cursor_position
	info "${TITLE}"
	save_indent

	touch "${TMP_OUT}"
	(
		tail -f "${TMP_OUT}" | while read -r LINE; do
			printf "\eK%s\r" "${LINE}"
		done
	) &
	local -i PID=$!

	try "$@" &>"${TMP_OUT}"
	local -i RET=${ERRNO}

	restore_indent
	restore_cursor_position
	printf "\eJ"
	if [[ ${RET} -eq 0 ]]; then
		info_success "${TITLE}"
	else
		info_error "${TITLE}"
		indent_stream cat "${TMP_OUT}"
		info_error "${TITLE}"
	fi
	return "${RET}"
}

function alternative_buffer_execute() {
	local TITLE="$1" RET
	shift

	if ! is_ci && is_tty && [[ ${ALTERNATIVE_BUFFER_ENABLED} == no ]] && [[ ${ALLOW_ALTERNATIVE_BUFFER-yes} == yes ]]; then
		ALTERNATIVE_BUFFER_ENABLED=yes
		local TMP_OUT
		TMP_OUT=$(create_temp_file "screen.output.txt")
		save_cursor_position
		info "save log to ${TMP_OUT}"
		save_indent

		info_warn "$TITLE"
		restore_cursor_position
		{
			stty -echo || true
			tput civis
			tput smcup
			tput home
			tput ed
		} >&2
		info_log "$TITLE"

		try "$@" &> >(tee "${TMP_OUT}")
		echo "ERRNO=$ERRNO ERRLOCATION=$ERRLOCATION"

		ALTERNATIVE_BUFFER_ENABLED=no
		{
			stty echo || true
			tput cnorm
			tput rmcup
			tput ed
		} >&2
		restore_indent

		if [[ ${ERRNO} -eq 0 ]]; then
			info_success "[screen] ${TITLE} (command '$*' return ${ERRNO})"
			info_note "[screen]     to see output, set ALLOW_ALTERNATIVE_BUFFER=no"
			return 0
		else
			info_error "[screen:${ERRNO}] ${TITLE}"
			indent_stream cat "${TMP_OUT}"
			info_error "[screen:${ERRNO}] ${TITLE}"
			return ${ERRNO}
		fi
	else
		control_ci group "${TITLE}"
		_run_group
		control_ci groupEnd
	fi
	unset _run_group
}
function term_reset() {
	_CURRENT_INDENT=''
	SAVED_INDENT=()
	if is_tty 2 && ! is_ci; then
		{
			stty echo || true
			tput cnorm
			tput oc
			tput rs2
			printf '\e[s'
			tput rmcup
			printf '\e[u'
			printf "\r\e[K"
		} >&2
	fi

	if [[ ${INSIDE_GROUP} -gt 0 ]]; then
		control_ci notice "Unclosed Group" "level: ${INSIDE_GROUP}"
		local -i i
		for ((i = INSIDE_GROUP; i > 0; i--)); do
			control_ci groupEnd
		done
	fi
}

function pause() {
	local _ msg=${1-'press any key.'}
	read -r -p "${msg}" _
	tput cuu1
}

function hyperlink() {
	local NAME=$1 URL=$2 ID=${3-}
	if [[ "$ID" ]]; then
		ID="id=$ID"
	fi

	printf '\e[4m\e]8;%s;%s\e\\%s\e]8;;\e\\\e[0m' "$ID" "$URL" "$NAME"
}

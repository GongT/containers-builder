function exportenv() {
	local -r NAME=$1 VALUE=$2
	if [[ $# -ne 2 ]]; then
		log "invalid call to exportenv: must have 2 arguments but got $#, $*"
	fi
	if grep -F "${NAME}=" /etc/environment; then
		die "conflict environment variable: ${NAME}"
	fi
	printf '%s=%q\n' "${NAME}" "${VALUE}" >>/etc/environment
}

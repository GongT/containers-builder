function exportenv() {
	local -r NAME=$1 VALUE=$2
	if [[ $# -ne 2 ]]; then
		log "invalid call to exportenv: must have 2 arguments but got $#, $*"
	fi
	printf '%s=%q\n' "${NAME}" "${VALUE}" >>/etc/environment
}

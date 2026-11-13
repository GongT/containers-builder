function log() {
	local MSG="$*"
	if [[ ${MSG:0:1} == "[" ]]; then
		echo "[entry]${MSG}" >&2
	else
		echo "[entry] ${MSG}" >&2
	fi
}

function die() {
	local MSG="$*"
	if [[ ${MSG:0:1} == "[" ]]; then
		log "[fatal]${MSG}"
	else
		log "[fatal] ${MSG}"
	fi
	exit 1
}

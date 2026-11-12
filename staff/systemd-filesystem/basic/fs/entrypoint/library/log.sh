function log() {
	echo "[entry] $*" >&2
}

function die() {
	echo "[entry][fatal] $*" >&2
	exit 1
}

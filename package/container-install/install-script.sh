function install_script() {
	install_script_as "$1" "$(basename "$1" .sh)"
}
function install_script_as() {
	local F BASE=$2
	F=$(realpath -m "$1")
	if [[ ! -f ${F} ]]; then
		die "Cannot found script file: ${F}"
	fi

	copy_file --mode 0755 "${F}" "${SCRIPTS_DIR}/${BASE}"
	echo "${SCRIPTS_DIR}/${BASE}"
}
function install_binary() {
	local F=$1 AS="${2-$(basename "$1" .sh)}"
	F=$(realpath --no-symlinks "${F}")
	write_file --nodir --mode 0755 "/usr/local/bin/${AS}" "$(head -n1 "${F}")
source '${F}'"
	info "installed binary: \e[38;5;2m${AS}"
}

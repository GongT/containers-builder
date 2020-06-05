function install_script() {
	local F BASE VAR_NAME=$2
	F=$(realpath -m "$1")
	if ! [[ -f "$F" ]]; then
		die "Cannot found script file: $F"
	fi
	BASE=$(basename "$F")

	mkdir -p /usr/share/scripts
	write_file "/usr/share/scripts/$BASE" < "$F"
	if is_installing; then
		chmod a+x "/usr/share/scripts/$BASE"
	fi
	declare -gr "$VAR_NAME=/usr/share/scripts/$BASE"
}
function install_binary() {
	local F=$1 AS="${2-$(basename "$1" .sh)}"
	if ! [[ -f "$F" ]]; then
		die "Cannot found script file: $F ($(pwd))"
	fi
	write_file "/usr/local/bin/$AS" < "$F"
	chmod a+x "/usr/local/bin/$AS"
	info "installed binary: \e[38;5;2m/usr/local/bin/$AS"
}

function install_script() {
	install_script_as "$1" "$(basename "$1")"
}
function install_script_as() {
	local F BASE=$2
	F=$(realpath -m "$1")
	if ! [[ -f $F ]]; then
		die "Cannot found script file: $F"
	fi

	mkdir -p /usr/share/scripts
	write_file "/usr/share/scripts/$BASE" <"$F"
	echo "/usr/share/scripts/$BASE"
}
function install_binary() {
	local F=$1 AS="${2-$(basename "$1" .sh)}"
	if ! [[ -f $F ]]; then
		die "Cannot found script file: $F ($(pwd))"
	fi
	write_executable_file "/usr/local/bin/$AS" "bash $F \"\$@\""
	info "installed binary: \e[38;5;2m/usr/local/bin/$AS"
}

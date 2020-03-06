function install_script() {
	local F=$1
	mkdir -p /usr/share/scripts
	if ! [[ -f "$F" ]]; then
		die "Cannot found script file: $F"
	fi
	cat "$F" | write_file "/usr/share/scripts/$F"
	chmod a+x "/usr/share/scripts/$F"
	echo "/usr/share/scripts/$F"
}
function install_binary() {
	local F=$1 AS="${2-$(basename "$1" .sh)}"
	if ! [[ -f "$F" ]]; then
		die "Cannot found script file: $F ($(pwd))"
	fi
	cat "$F" | write_file "/usr/local/bin/$AS"
	chmod a+x "/usr/local/bin/$AS"
	info "installed binary: \e[38;5;2m/usr/local/bin/$AS"
}

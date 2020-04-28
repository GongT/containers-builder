declare -a _REG_FILES=()

function write_file() {
	local F="$1"
	_REG_FILES+=("$F")
	if [[ ! -d "$(dirname "$F")" ]]; then
		echo -e "\e[2m * create directory: $F\e[0m" >&2
		mkdir -p "$(dirname "$F")"
	fi
	echo -e "\e[2m * write file: $F\e[0m" >&2
	cat > "$F"
}
function find_command() { 
    env sh --noprofile --norc -c "command -v \"$@\"" -- "$1"
}

declare -a _REG_FILES=()

function write_file() {
	local F="$1"
	echo -e "\e[2m * write file: $F\e[0m" >&2
	_REG_FILES+=("$F")
	cat > "$F"
}

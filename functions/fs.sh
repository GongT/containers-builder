declare -a _REG_FILES=()

function write_file() {
	local -r F="$1"
	if is_uninstalling; then
		if [[ -e "$F" ]]; then
			echo -e "\e[2m * remove file: $F\e[0m" >&2
			unlink "$F"
		fi
		return
	fi

	_REG_FILES+=("$F")
	if [[ ! -d "$(dirname "$F")" ]]; then
		echo -e "\e[2m * create directory: $F\e[0m" >&2
		mkdir -p "$(dirname "$F")"
	fi
	echo -ne "\e[2m * write file: $F" >&2

	if [[ -e "$F" ]]; then
		local -r TMPF="/tmp/${RANDOM}"
		cat >"$TMPF"
		if [[ "$(<$TMPF)" = "$(<$F)" ]]; then
			echo -ne " - same" >&2
		else
			cat "$TMPF" >"$F"
		fi
		rm -f "$TMPF"
	else
		cat >"$F"
	fi
	echo -e "\e[0m" >&2
}
function find_command() {
	env sh --noprofile --norc -c "command -v \"$@\"" -- "$1"
}

#!/usr/bin/env bash

declare -a _REG_FILES=()

function write_executable_file_share() {
	write_executable_file "$@"
}

function write_executable_file() {
	write_file "$@"
	if is_installing; then
		chmod a+x "$1"
	fi
}

function write_file_share() {
	write_file "$@"
}

function write_file() {
	_arg_ensure_finish
	local -r F="$1"
	if is_uninstalling; then
		if [[ -e $F ]]; then
			echo -e "\e[2m * remove file: $F\e[0m" >&2
			unlink "$F"
		fi
		if [[ $# -eq 1 ]]; then
			cat >/dev/null
		fi
		return
	fi

	_REG_FILES+=("$F")
	if [[ ! -d "$(dirname "$F")" ]]; then
		echo -e "\e[2m * create directory: $F\e[0m" >&2
		mkdir -p "$(dirname "$F")"
	fi
	echo -ne "\e[2m * write file: $F" >&2

	if [[ $# -eq 1 ]]; then
		if [[ -e $F ]]; then
			local -r TMPF="/tmp/${RANDOM}"
			cat >"$TMPF"
			if [[ "$(<$TMPF)" == "$(<$F)" ]]; then
				echo -ne " - same" >&2
			else
				cat "$TMPF" >"$F"
			fi
			rm -f "$TMPF"
		else
			cat >"$F"
		fi
	else
		local -r CONTENT=$2
		if [[ -e $F ]] && [[ $CONTENT == "$(<$F)" ]]; then
			echo -ne " - same" >&2
		else
			echo "$2" >"$F"
		fi
	fi
	echo -e "\e[0m" >&2
}
function find_command() {
	env -i "PATH=$PATH" "$SHELL" --noprofile --norc -c "command -v '$1'"
}
function ensure_symlink() {
	local LINK_FILE=$1 TARGET=$2 CURR
	if [[ -L $LINK_FILE ]]; then
		CURR=$(readlink --canonicalize-missing --no-newline "$LINK_FILE")
		if [[ $CURR != "$TARGET" ]]; then
			unlink "$LINK_FILE"
		else
			return
		fi
	elif [[ -f $LINK_FILE ]]; then
		info_warn "replacing normal file $LINK_FILE with a symlink"
		unlink "$LINK_FILE"
	elif [[ -d $LINK_FILE ]]; then
		die "ensure_symlink: element exists and is a folder"
	fi

	mkdir -p "$(dirname "$LINK_FILE")"
	ln -s "$TARGET" "$LINK_FILE"
}

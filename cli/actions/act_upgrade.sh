#!/usr/bin/env bash

function do_upgrade() {
	mapfile -t DISABLED < <(do_ls disabled)

	cd "$SYSTEM_UNITS_DIR"

	mapfile -t SCRIPT_LIST < <(grep 'INSTALLER_SCRIPT=' . -R | sed -E 's/^.+INSTALLER_SCRIPT=//g' | sort | uniq)

	cd "${TMPDIR:-/tmp}"

	export SYSTEMD_RELOAD=no DISABLE_SYSTEMD_ENABLE=yes
	for FILE in "${SCRIPT_LIST[@]}"; do
		BASE=$(basename "$(dirname "$FILE")" .sh)
		echo -ne "\e[38;5;14m$BASE \e[0;2m($FILE) ...\e[0m "

		LOG="$BASE.log"
		if ! bash "$FILE" &>"$LOG"; then
			cat "$LOG" >&2
			echo -e "\e[38;5;9mFailed!\e[0m"
		else
			echo -e "\e[38;5;10mSuccess!\e[0m"
		fi
	done

	echo "daemon-reload..."
	systemctl daemon-reload
	do_ls enabled >/dev/null

	do_ls enabled | mapfile -t LIST_RESULT
	if [[ "${#LIST_RESULT[@]}" ]]; then
		systemctl -q reenable "${LIST_RESULT[@]}"
	fi

	echo "All Done!"
}

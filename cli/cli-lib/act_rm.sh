#!/usr/bin/env bash

do_rm() {
	go_home
	local T=$1 FILES I
	mapfile -t FILES < <(systemctl list-unit-files "$T.pod@.service" "$T.pod.service" --all --no-pager --no-legend | awk '{print $1}')

	for I in "${FILES[@]}"; do
		local OVERWRITE="/etc/systemd/system/$I.d"
		if [[ -d $OVERWRITE ]]; then
			echo "remove directory: $OVERWRITE"
			rm -rf "$OVERWRITE"
		fi

		echo -ne "disable (and stop) service $I\n    "
		systemctl disable --now --no-block "$I" || true

		local F="/usr/lib/systemd/system/$I"
		if [[ -e $F ]]; then
			echo "remove service file: $F"
			rm -f "$F"
		fi
	done

	if [[ ${#FILES[@]} -gt 0 ]]; then
		systemctl daemon-reload
	fi
}

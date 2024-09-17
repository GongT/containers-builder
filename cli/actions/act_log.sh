#!/usr/bin/env bash

function do_log() {
	IARGS=() NARGS=()
	for I; do
		if [[ $I == -f ]]; then
			NARGS+=(-f)
		else
			IARGS+=("$I")
		fi
	done

	if [[ ${#IARGS[@]} -ne 1 ]]; then
		die "must 1 argument"
	fi
	V=${IARGS[0]}
	if [[ $V != *.pod ]] && [[ $V != *.pod@* ]]; then
		V+=".pod"
	fi
	IID=$(systemctl show -p InvocationID --value "$V.service")
	echo "InvocationID=$IID"
	journalctl "${NARGS[@]}" "_SYSTEMD_INVOCATION_ID=$IID"
}

function do_logs() {
	LARGS=() NARGS=()
	for I; do
		if [[ $I == -f ]]; then
			NARGS+=(-f)
		else
			if [[ $I != *.pod ]] && [[ $I != *.pod@* ]]; then
				I+=".pod"
			fi
			LARGS+=(-u "$I")
		fi
	done
	if [[ ${#LARGS[@]} -eq 0 ]]; then
		for i in $(do_ls); do
			LARGS+=("-u" "$i")
		done
	fi
	journalctl "--since=1h ago" "${LARGS[@]}" "${NARGS[@]}"
}

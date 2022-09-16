#!/usr/bin/env bash

declare -i _TABLE_COLS=0
declare -a _TABLE_DATA=()
declare -a _TABLE_WIDTH=()

function table_start() {
	_TABLE_COLS=$#
	_TABLE_DATA=()
	for I; do
		_TABLE_DATA+=("\e[1m$I\e[0m")
	done
	_TABLE_WIDTH=()
	for I; do
		I=$(echo "$I" | wc -L)
		I=$((I + 2))
		_TABLE_WIDTH+=("$I")
	done
}
function table_row() {
	local W I INDEX
	_TABLE_DATA+=("$@")
	for I in $(seq 1 $#); do
		INDEX=$((I - 1))
		W=$(echo -ne "${!I}" | sed 's/\x1b\[[0-9;]*m//g' | wc -L)
		W=$((W + 2))
		if [[ $W -gt ${_TABLE_WIDTH[$INDEX]} ]]; then
			_TABLE_WIDTH[$INDEX]="$W"
		fi
	done
}
function table_print() {
	while [[ ${#_TABLE_DATA[@]} -gt 0 ]]; do
		for I in $(seq 0 $((_TABLE_COLS - 1))); do
			DATA=${_TABLE_DATA[0]}
			_TABLE_DATA=("${_TABLE_DATA[@]:1}")

			MW=${_TABLE_WIDTH[$I]}
			W=$(echo -e "${DATA}" | sed 's/\x1b\[[0-9;]*m//g' | wc -L)

			echo -ne "$DATA"
			printf "%*s" $((MW - W)) ''
		done
		echo
	done
}

function do_default() {
	local LoadState ActiveState SubState UnitFileState StateChangeTimestamp StatusText MemoryCurrent CPUUsageNSec
	local SERVICES SRV
	local T_ENABLE='' T_STATE='' T_TIME='' T_RES=''

	table_start "Name" "Enabled" "State" "Time" "Resource"

	mapfile -t SERVICES < <(do_ls)
	for SRV in "${SERVICES[@]}" "${CONTROL_SERVICES[@]}"; do
		while read -r line; do
			local "$line"
		done < <(systemctl show "$SRV" -p LoadState,ActiveState,SubState,UnitFileState,StateChangeTimestamp,StatusText,MemoryCurrent,CPUUsageNSec)

		if [[ $LoadState == loaded ]]; then
			T_STATE=""
			if [[ $ActiveState == active ]]; then
				T_STATE+="\e[38;5;10m$ActiveState\e[0m"
				NR_WARN='38;5;11'
			elif [[ $ActiveState == deactivating ]] || [[ $ActiveState == activating ]]; then
				T_STATE+="\e[38;5;2m$ActiveState\e[0m"
				NR_WARN='38;5;1'
			elif [[ $ActiveState == inactive ]]; then
				T_STATE+="\e[38;5;9m$ActiveState\e[0m"
				NR_WARN='2'
			else
				T_STATE+="\e[38;5;9m$ActiveState\e[0m"
				NR_WARN='38;5;9'
			fi
			T_STATE+='/'
			if [[ $SubState == running ]]; then
				T_STATE+="\e[38;5;10m$SubState\e[0m"
			else
				T_STATE+="\e[${NR_WARN}m${SubState}\e[0m"
			fi
		else
			T_STATE="\e[38;5;9m$LoadState\e[0m"
		fi
		if [[ $UnitFileState == enabled ]]; then
			T_ENABLE='38;5;10'
		elif [[ $UnitFileState == static ]]; then
			T_ENABLE='1'
		else
			T_ENABLE='38;5;9'
		fi

		if [[ $LoadState == not-found ]] || [[ ! $StateChangeTimestamp ]]; then
			T_TIME=''
		else
			T_TIME=$(systemd-analyze timestamp "$StateChangeTimestamp" | grep 'From now:' | sed -E 's/\s*From now: //g' || echo 'NaN')
			T_TIME="$StatusText since $T_TIME"
		fi

		if [[ $SubState != running ]]; then
			T_RES="N/A"
		else
			T_RES=''
			local -i CPU_SEC=$((CPUUsageNSec / 1000 / 1000 / 1000))
			if [[ $CPU_SEC -gt 3600 ]]; then
				T_RES+="\e[38;5;11m"
			fi
			T_RES+=$(
				systemd-analyze timespan "$CPU_SEC" | grep 'Human:' | sed -E 's/\s*Human: //g; s/min/m/g;s/ //g'
			)
			if [[ $CPU_SEC -gt 3600 ]]; then
				T_RES+="\e[0m"
			fi
			T_RES+='/'

			if [[ $MemoryCurrent -gt 0 ]]; then
				local MEM_MB=$((MemoryCurrent / 1024 / 1024))
				if [[ $MEM_MB -gt 1024 ]]; then
					T_RES+="\e[38;5;11m$((MEM_MB / 1024))G\e[0m"
				else
					T_RES+="${MEM_MB}M"
				fi
			else
				T_RES+='--'
			fi
		fi

		table_row "$SRV" "\e[${T_ENABLE}m${UnitFileState}\e[0m" "$T_STATE" "$T_TIME" "$T_RES"
	done

	table_print
}

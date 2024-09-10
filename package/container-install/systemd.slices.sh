#!/usr/bin/env bash

declare -A _S_BODY_CONFIG

function systemd_slice_type() {
	local -i OOM_ADJUST=${2:-0}
	if [[ $1 == "entertainment" ]]; then
		_S_BODY_CONFIG[Slice]="services-entertainment.slice"
		_S_BODY_CONFIG[OOMPolicy]="stop"
		_S_BODY_CONFIG[OOMScoreAdjust]="$((OOM_ADJUST + 100))"
	elif [[ $1 == "idle" ]]; then
		_S_BODY_CONFIG[Slice]="services-idle.slice"
		_S_BODY_CONFIG[OOMPolicy]="kill"
		_S_BODY_CONFIG[OOMScoreAdjust]="$((OOM_ADJUST + 800))"
	elif [[ $1 == "infrastructure" ]]; then
		_S_BODY_CONFIG[Slice]="services-infrastructure.slice"
		_S_BODY_CONFIG[OOMPolicy]="continue"
		_S_BODY_CONFIG[OOMScoreAdjust]="$((OOM_ADJUST - 1000))"
	elif [[ $1 == "normal" ]]; then
		_S_BODY_CONFIG[Slice]="services-normal.slice"
		_S_BODY_CONFIG[OOMPolicy]=stop
		_S_BODY_CONFIG[OOMScoreAdjust]="${OOM_ADJUST}"
	else
		die "unknown systemd slice type: $1"
	fi
}

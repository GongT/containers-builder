#!/usr/bin/env bash

function is_ci() {
	[[ ${CI+found} == "found" ]] && [[ "$CI" ]]
}

if is_ci; then
	info_note "CI=${CI}"
	export CI
else
	unset CI
	info_note "CI=*not set*"
fi

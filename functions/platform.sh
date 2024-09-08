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

function guard_root_only() {
	if ! is_root; then
		die "This action must run by root."
	fi
}

function guard_no_root() {
	if is_root; then
		die "This action can not run by root."
	fi
}

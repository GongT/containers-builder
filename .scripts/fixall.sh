#!/usr/bin/env bash

set -Eeuo pipefail
shopt -s lastpipe

declare -i WANT_CODE=$1
shift

CHECK=(
	shellcheck "$@" --norc --enable=all --check-sourced --external-sources
)

x() {
	echo -e "\e[2m + $*\e[0m" >&2
	"$@"
}

ERRORS=()
(x "${CHECK[@]}" "--exclude=${WANT_CODE}" --wiki-link-count=9999 2>&1 | grep -E '/wiki/SC[0-9]{4}' | grep -oE '[0-9]{4}' || true) | while read -r line; do
	if [[ ${line} -ne ${WANT_CODE} ]]; then
		ERRORS+=("${line}")
	fi
done

if [[ ${#ERRORS[@]} -eq 0 ]]; then
	echo "no error."
	exit 0
fi
ESTR=$(printf ',%s' "${ERRORS[@]}")
ESTR=${ESTR:1}

echo "fixing errors: ${WANT_CODE}, excludes: ${ESTR}"
x "${CHECK[@]}" "--include=${WANT_CODE}" "--exclude=${ESTR}" --format=diff | patch -p 1

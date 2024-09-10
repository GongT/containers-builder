#!/usr/bin/env bash

set -Eeuo pipefail
shopt -s lastpipe

x() {
	echo -e "\e[2m + $*\e[0m" >&2
	"$@"
}
die() {
	echo -e "\e[38;5;9m$*\e[0m" >&2
	exit 1
}
congratulations() {
	echo -e "\e[38;5;10m$*\e[0m" >&2
	exit 0
}

if [[ $# -lt 2 || ! $1 =~ ^[0-9]+$ ]]; then
	die "Usage: $0 <NUMBER to fix> <...files>"
fi
if ! git diff --exit-code &>/dev/null; then
	echo "refuse run. not inside git repo, or has unstaged file. you must run git add before continue."
	exit 1
fi

declare -i WANT_CODE="$1"
shift

CHECK=(
	shellcheck "$@" --norc --enable=all --check-sourced --external-sources
)

ERRORS=()
WANT_IS_HAPPE=0
(x "${CHECK[@]}" --wiki-link-count=9999 | grep -E '/wiki/SC[0-9]{4}' | grep -oE '[0-9]{4}' || true) | while read -r line; do
	if [[ ${line} -eq ${WANT_CODE} ]]; then
		WANT_IS_HAPPE=1
	else
		ERRORS+=("${line}")
	fi
done

if [[ ${WANT_IS_HAPPE} -eq 0 ]]; then
	congratulations "no error with code ${WANT_CODE}!"
fi

ESTRARG=()
if [[ ${#ERRORS[@]} -ne 0 ]]; then
	ESTR=$(printf ',%s' "${ERRORS[@]}")
	ESTRARG+=("--exclude=${ESTR:1}")
fi

echo "fixing errors: ${WANT_CODE}"

set +Eeo pipefail

x "${CHECK[@]}" "--include=${WANT_CODE}" "${ESTRARG[@]}" --format=diff  | patch --reject-file=/tmp/rej --forward -p 1
rm -f /tmp/rej

congratulations "all files fixed!"

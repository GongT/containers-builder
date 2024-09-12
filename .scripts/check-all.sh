#!/usr/bin/env bash
set -e

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
cd ..

printf '\ec'
shellcheck "$@" --check-sourced --external-sources \
	functions-build.sh \
	functions-install.sh \
	install-cli-tool.sh \
	cli/bin.sh \
	cli-lib/*.sh \
	package/standard_build_steps/*.sh \
	staff/*/*.sh

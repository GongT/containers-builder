#!/usr/bin/env bash

# shellcheck source=./functions-build.sh disable=SC2312
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/functions-build.sh"

function get_up_to_date_image() {
	local HASH="$1"

	set +Eeuo pipefail

	"${BUILDAH}" images \
		--filter "label=${LABELID_RESULT_HASH}=${HASH}" \
		--noheading \
		--format '{{.ID}} {{.Name}}' | grep -v --fixed-strings -- "<none>" | awk '{print $1}'

	set -Eeuo pipefail
}

die "no use script"

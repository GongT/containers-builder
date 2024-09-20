#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "./package/include.sh"

arg_finish "$@"

GITDIR=$(git rev-parse --git-dir)
GITDIR=$(realpath -e "${GITDIR}")

copy_file --mode 0755 .scripts/git-hook-pre-commit.sh "${GITDIR}/hooks/pre-commit"

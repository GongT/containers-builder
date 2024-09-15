#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export PROJECT_NAME="bash-test"
source ../../package/include.sh

ARR=(1 2 3 ' <- 4 5 6 -> ' '🥺')
DATA=$(json_array "${ARR[@]}")
echo "JSON=$DATA"

ARR2=()
json_array_get_back ARR2 "$DATA"
echo "restore: ${#ARR2[@]}"
declare -p ARR2

declare -A MAP=([0]=1 [1]=2 [' wow such doge ']=' hello~ ' ['🥺']='👍')
DATA=$(json_map MAP)
echo "JSON=$DATA"

declare -A MAP2=()
json_map_get_back MAP2 "$DATA"
echo "restore: ${#MAP2[@]}"
declare -p MAP2

info done

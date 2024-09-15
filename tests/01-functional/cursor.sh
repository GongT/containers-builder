#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export PROJECT_NAME="bash-test"
source ../../package/include.sh

function print_garbage() {
	local -i LINES=$1 i
	for ((i = 1; i <= LINES; i++)); do
		echo " -- -- -- -- -- -- -- -- ${i}/${LINES}"
	done
	return 0
}

info "test start"
soft_clear
pause 'im at bottom left'

save_cursor_position
print_garbage 5
restore_cursor_position
pause 'below should have 5 empty line'

save_cursor_position
print_garbage 80
restore_cursor_position
pause 'im at bottom left again'

save_cursor_position
print_garbage 10
restore_cursor_position

alternative_buffer_execute TEST print_garbage 100
pause 'im at middle'

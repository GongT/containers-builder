#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export PROJECT_NAME="bash-test"
source ../../package/include.sh

function func_out() {
	echo ":out"
	func_mid
	echo "-out $? $ERRNO"
}

function func_mid() {
	echo ":mid"
	func_in
	echo "-mid $? $ERRNO"
	return 1

}

function func_in() {
	echo ":in"
	try false
	echo "-in $? $ERRNO"
	return 1
}

try func_out
echo "done $ERRNO, $ERRLOCATION"

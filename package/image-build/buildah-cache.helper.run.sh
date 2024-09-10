#!/usr/bin/env bash

## buildah_cache_run ID ScriptFilePath [--buildah-arguments ...] -- [bash args...]
function buildah_cache_run() {
	local NAME=$1
	shift
	local -r BUILD_SCRIPT=$1
	shift

	local -a BASH_ARGS=()
	local -a RUN_ARGS=()
	local -a HASH_FOLDERS=()
	if [[ $# -gt 0 ]]; then
		local SPFOUND=no
		for I; do
			if [[ ${SPFOUND} == yes ]]; then
				BASH_ARGS+=("${I}")
			elif [[ ${I} == '--' ]]; then
				SPFOUND=yes
			else
				RUN_ARGS+=("${I}")
				if [[ ${I} == "--volume="* ]]; then
					local X="${I//:*/}"
					HASH_FOLDERS+=("${X#--volume=}")
				fi
			fi
		done
		if [[ ${SPFOUND} == no ]]; then
			die "argument list require a '--'"
		fi
	fi

	_hash_cb() {
		echo "last: ${BUILDAH_LAST_IMAGE}"
		echo -n 'script: '
		cat "${BUILD_SCRIPT}"
		echo "run: ${RUN_ARGS[*]}"
		echo "bash: ${BASH_ARGS[*]}"
		git ls-tree -r -t HEAD "${HASH_FOLDERS[@]}" || true
	}
	_build_cb() {
		local CONTAINER
		CONTAINER=$(new_container "$1" "${BUILDAH_LAST_IMAGE}")

		buildah run "--cap-add=CAP_SYS_ADMIN" "${RUN_ARGS[@]}" "${CONTAINER}" \
			bash -s - "${BASH_ARGS[@]}" <"${BUILD_SCRIPT}"
	}

	buildah_cache "${NAME}" _hash_cb _build_cb

	unset -f _hash_cb _build_cb
}

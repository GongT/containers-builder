function setup_systemd() {
	local STEP="配置镜像中的systemd"
	local CACHE_BRANCH="$1"
	local __hash_cb __build_cb

	shift
	local I_ARTS=("basic" "$@")
	info "setup systemd with arguments: ${I_ARTS[*]}"

	function __hash_cb() {
		echo "version:2"
		echo "${I_ARTS[*]}"
		hash_path "${COMMON_LIB_ROOT}/staff/systemd-filesystem"
	}
	function __build_cb() {
		local C="$1"

		local TARGS=() TARG='' I=''
		for TARG in "${I_ARTS[@]}"; do
			if [[ ${TARG} == *"="* ]]; then
				TARGS+=("${TARG}")
				continue
			fi

			local ENVS=() PLUGIN="${TARG}"
			local FILES="${COMMON_LIB_ROOT}/staff/systemd-filesystem/${PLUGIN}/fs"
			local SETUP_SRC="${COMMON_LIB_ROOT}/staff/systemd-filesystem/${PLUGIN}/setup.sh"
			local PREFIX_FN="systemd_use_${TARG}"
			if ! [[ -e ${FILES} ]] && ! [[ -e ${SETUP_SRC} ]] && ! function_exists "${PREFIX_FN}"; then
				die "missing systemd plugin: ${TARG}"
			fi

			info "	* ${PLUGIN}"
			if function_exists "${PREFIX_FN}"; then
				info "	  -> call ${PREFIX_FN}"
				local "${TARGS[@]}"
				"${PREFIX_FN}" "${C}"
			fi
			if [[ -e ${FILES} ]]; then
				info "	  -> copy filesystem"
				buildah copy "${C}" "${FILES}" "/"
			fi
			if [[ -e ${SETUP_SRC} ]]; then
				for I in "${TARGS[@]}"; do
					ENVS+=("--env=${I}")
				done
				TARGS=()
				info "	  -> execute setup:"
				buildah run "--env=PROJECT=${CACHE_BRANCH}" "${ENVS[@]}" "${C}" bash <"${SETUP_SRC}"
			fi
		done

		if [[ ${#TARGS[@]} -gt 0 ]]; then
			die "extra arguments: ${TARGS[*]}"
		fi

		systemd_use_basic "${C}"
	}

	export BUILDAH_HISTORY=false
	buildah_cache2 "${CACHE_BRANCH}" __hash_cb __build_cb
	unset BUILDAH_HISTORY
	SYSTEMD_PLUGINS=()
}

function systemd_use_autonginx() {
	if ! [[ -e "fs/opt/nginx.conf" ]]; then
		die "missing $(pwd)/fs/opt/nginx.conf"
	fi
}

function systemd_use_basic() {
	buildah config '--entrypoint=["/entrypoint/entrypoint.sh"]' '--cmd=["--systemd"]' "$1"
}

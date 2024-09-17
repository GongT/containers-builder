#!/usr/bin/env bash

TMPREPODIR=

function create_dnf_arguments() {
	local -nr VARREF="$1"
	if ! variable_is_array "$1"; then
		die "$1 is not array"
	fi
	shift

	VARREF=(
		"--env=PATH=/usr/local/bin:/usr/bin:/usr/sbin"
		"--env=RPMDB=${DNF_ENVIRONMENT_RPMDB}"
		"--cap-add=CAP_SYS_ADMIN" # to mount
		"--env=FEDORA_VERSION=${FEDORA_VERSION}"
		"--env=WHO_AM_I=mdnf"
	)

	if [[ $# -gt 0 ]]; then
		local SRC
		SRC=$(realpath -e "$1")
		local -r IN_ROOT='/install-root'
		VARREF+=("--env=RUNMODE=guest")
		VARREF+=("--volume=${SRC}:/install-root")
	else
		local -r IN_ROOT=""
		VARREF+=("--env=RUNMODE=host")
	fi
	VARREF+=(
		"--mount=type=tmpfs,destination=${IN_ROOT}/var/lib/dnf"
		"--volume=${PRIVATE_CACHE}/dnf/repos:${IN_ROOT}/var/lib/dnf/repos"
		"--volume=${PRIVATE_CACHE}/dnf/pkgs:${IN_ROOT}/var/cache/dnf"
	)
	mkdir -p "${PRIVATE_CACHE}/dnf/repos" "${PRIVATE_CACHE}/dnf/pkgs"
}

declare _DNF_ENVIRONMENT_CID
declare -a DNF_ENVIRONMENT_ENABLES=()
declare -a DNF_ENVIRONMENT_REPOS=()
declare DNF_ENVIRONMENT_RPMDB=keep
function dnf_use_environment() {
	if is_recording_steps; then
		_DNF_ENVIRONMENT_CID=fake
		return
	fi

	DNF_ENVIRONMENT_ENABLES=()
	DNF_ENVIRONMENT_REPOS=()
	DNF_ENVIRONMENT_RPMDB=remove
	local ARG DNF
	for ARG; do
		if [[ $ARG == '--enable='* ]]; then
			DNF_ENVIRONMENT_ENABLES+=("$(split_assign_argument_value "${ARG}")")
		elif [[ $ARG == '--repo='* ]]; then
			DNF_ENVIRONMENT_REPOS+=("$(split_assign_argument_value "${ARG}")")
		elif [[ $ARG == '--rpmdb=remove' || $ARG == '--rpmdb=keep' ]]; then
			DNF_ENVIRONMENT_RPMDB=$(split_assign_argument_value "${ARG}")
		else
			die "invalid argument: ${ARG}"
		fi
	done
	local CACHE_ID=''
	CACHE_ID=$(echo "${DNF_ENVIRONMENT_ENABLES[*]} ${DNF_ENVIRONMENT_REPOS[*]} ${DNF_ENVIRONMENT_RPMDB}" | md5sum | awk '{print "dnf-" $1}')
	info "create dnf environment: ${CACHE_ID} with ${#DNF_ENVIRONMENT_ENABLES[@]} repos in ${#DNF_ENVIRONMENT_REPOS[@]} package, rpmdb=${DNF_ENVIRONMENT_RPMDB}"

	if container_exists "${CACHE_ID}"; then
		DNF=$(container_get_digist "${CACHE_ID}")
		info_note "use exists: ${DNF}"
	else
		control_ci group "prepare new dnf container"
		DNF=$(new_container "${CACHE_ID}-work" "registry.fedoraproject.org/fedora:${FEDORA_VERSION}")
		collect_temp_container "${CACHE_ID}-work"
		buildah copy "${DNF}" "${COMMON_LIB_ROOT}/staff/mdnf/fs" /
		buildah config "--env=PATH=/usr/local/bin:/usr/bin:/usr/sbin" "${DNF}"

		local EXTRA TMPSCRIPT=$(create_temp_file "dnf.lib.sh")

		local DNF_REPOS=() FILE
		for NAME in "${DNF_ENVIRONMENT_REPOS[@]}"; do
			if [[ ${NAME} == http://* || ${NAME} == https://* ]]; then
				FILE=$(download_file "${NAME}" "$(basename "${NAME}")")
				buildah copy "${DNF}" "${FILE}" /opt/repos/
			elif [[ -e ${NAME} ]]; then
				buildah copy "${DNF}" "$(realpath -m "${NAME}")" /opt/repos/
			else
				die "unknown DNF repo type: ${NAME} (allow rpm/repo file)"
			fi
		done

		EXTRA=$(declare -p DNF_ENVIRONMENT_ENABLES)
		construct_child_shell_script "${TMPSCRIPT}" "${COMMON_LIB_ROOT}/staff/mdnf/lib.sh" "${EXTRA}"
		buildah copy "${DNF}" "${TMPSCRIPT}" /usr/lib/lib.sh

		local -a CONTAINER_ARGS=()
		create_dnf_arguments CONTAINER_ARGS
		buildah_run_shell_script "${CONTAINER_ARGS[@]}" "${DNF}" "${COMMON_LIB_ROOT}/staff/mdnf/prepare.sh" </dev/null
		buildah rename "${DNF}" "${CACHE_ID}"
		control_ci groupEnd
	fi

	_DNF_ENVIRONMENT_CID="${DNF}"
}
function call_dnf_install() {
	if ! variable_bounded _DNF_ENVIRONMENT_CID; then
		die "no call to dnf_use_environment"
	fi
	local -r WORKING_CONTAINER="$1" PACKAGE_FILE="$2" POST_SCRIPT="${3-}" DNF="${_DNF_ENVIRONMENT_CID}"

	local TMPSCRIPT ROOT

	if [[ ! -e ${PACKAGE_FILE} ]]; then
		die "missing list file: ${PACKAGE_FILE}"
	fi

	local -a PKGS=()
	read_list_file "${PACKAGE_FILE}" PKGS

	call_dnf_with_guest "${WORKING_CONTAINER}" "${POST_SCRIPT}" install "${PKGS[@]}"
}

function call_dnf_with_guest() {
	local -r WORKING_CONTAINER="$1" POST_SCRIPT="$2"
	local -a CONTAINER_ARGS=() DNF_ARGS=("${@:3}")

	if [[ -n ${POST_SCRIPT} ]]; then
		if [[ ! -e ${POST_SCRIPT} ]]; then
			die "missing script file: ${POST_SCRIPT}"
		fi
		local POST_SCRIPT_ABS
		POST_SCRIPT_ABS=$(realpath -e "${POST_SCRIPT}")
		CONTAINER_ARGS+=("--volume=${POST_SCRIPT_ABS}:/tmp/dnf.postscript.sh:ro")
	fi

	function _run_group() {
		local INSTALL_ROOT
		INSTALL_ROOT=$(buildah mount "${WORKING_CONTAINER}")
		info_note "working root physical location: ${INSTALL_ROOT}"
		create_dnf_arguments CONTAINER_ARGS "${INSTALL_ROOT}"

		buildah run "${CONTAINER_ARGS[@]}" "${_DNF_ENVIRONMENT_CID}" \
			/usr/local/bin/dnf "${DNF_ARGS[@]}"

		buildah unmount "${WORKING_CONTAINER}"

		info_note "DNF run FINISH"
	}

	alternative_buffer_execute \
		"run for: ${WORKING_CONTAINER}, script: ${POST_SCRIPT-not present}, cmdline: dnf ${DNF_ARGS[*]}" \
		_run_group
	unset -f _run_group
}

function call_dnf_without_guest() {
	if ! variable_bounded _DNF_ENVIRONMENT_CID; then
		die "no call to dnf_use_environment"
	fi

	local -a CONTAINER_ARGS=()
	create_dnf_arguments CONTAINER_ARGS
	buildah run "${CONTAINER_ARGS[@]}" "${_DNF_ENVIRONMENT_CID}" \
		"/usr/local/bin/dnf" "$@" </dev/null
}

function dnf_list_version() {
	local FILE=$1 PKGS=() TMPF

	TMPF=$(create_temp_file "dnf.list.output.txt")
	mapfile -t PKGS <"${FILE}"

	try call_dnf_without_guest list --quiet "${PKGS[@]}" >"${TMPF}"
	if [[ $ERRNO -ne 0 ]]; then
		info_error "[dnf:${ERRNO}] failed list package versions"
		cat "${TMPF}"
		info_error "[dnf:${ERRNO}] failed list package versions"
		return 1
	fi
	RET=$(grep -v --fixed-strings i686 "${TMPF}" | grep --fixed-strings '.' | awk '{print $1 " = " $2}')
	info_log "================================================="
	indent_multiline "${RET}"
	info_log "================================================="

	echo "${RET}"
}

function dnf_install_step() {
	local CACHE_NAME="$1"
	local PKG_LIST_FILE="$2"
	local POST_SCRIPT="${3-}"

	if [[ ! -e ${PKG_LIST_FILE} ]]; then
		die "missing install list file: ${PKG_LIST_FILE}"
	fi
	if [[ -n ${POST_SCRIPT} && ! -e ${POST_SCRIPT} ]]; then
		die "missing post install script: ${POST_SCRIPT}"
	fi

	_dnf_hash_cb() {
		info_log "dnf install (list file: ${PKG_LIST_FILE})..."
		cat "${PKG_LIST_FILE}"
		info_note "   listing versions..."
		dnf_list_version "${PKG_LIST_FILE}"
		cat "${POST_SCRIPT}"
	}
	_dnf_build_cb() {
		local CONTAINER="$1"
		call_dnf_install "${CONTAINER}" "${PKG_LIST_FILE}"
	}

	if [[ ${FORCE_DNF+found} != found ]]; then
		local FORCE_DNF=""
	fi

	if [[ -z ${STEP-} ]]; then
		STEP="安装系统依赖"
	fi

	BUILDAH_FORCE="${FORCE_DNF}" buildah_cache "${CACHE_NAME}" _dnf_hash_cb _dnf_build_cb
	unset -f _dnf_hash_cb _dnf_build_cb
}

function dnf() {
	die "deny run dnf on host!"
}

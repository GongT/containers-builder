#!/usr/bin/env bash

TMPREPODIR=

function create_dnf_arguments() {
	local -nr VARREF="$1"
	if ! variable_is_array "$1"; then
		die "参数不是数组: $1"
	fi
	shift

	VARREF+=(
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
		"--volume=${PRIVATE_CACHE}/dnf/pkgs:${IN_ROOT}/var/cache/libdnf5"
	)
	mkdir -p "${PRIVATE_CACHE}/dnf/repos" "${PRIVATE_CACHE}/dnf/pkgs"
}

declare _DNF_ENVIRONMENT_CID
declare -a DNF_ENVIRONMENT_ENABLES=()
declare -a DNF_ENVIRONMENT_REPOS=()
declare DNF_ENVIRONMENT_RPMDB=keep
function dnf_use_environment() {
	if is_recording_steps; then
		info "创建 dnf 环境: 假的 (因正在记录中而跳过)"
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
			die "参数异常: ${ARG}"
		fi
	done
	local CACHE_ID=''
	CACHE_ID=$(echo "${DNF_ENVIRONMENT_ENABLES[*]} ${DNF_ENVIRONMENT_REPOS[*]}" | md5sum | awk '{print "dnf-" $1}')
	info "创建 dnf 环境: ${CACHE_ID} 包含 ${#DNF_ENVIRONMENT_ENABLES[@]} 个启用的仓库和 ${#DNF_ENVIRONMENT_REPOS[@]} 个包仓库"

	if container_exists "${CACHE_ID}"; then
		DNF=$(container_get_digist "${CACHE_ID}")
		info_note "使用已存在的: ${DNF}"
	else
		control_ci group "准备新的 DNF 容器"
		DNF=$(new_container "${CACHE_ID}-work" "quay.io/fedora/fedora:${FEDORA_VERSION}")
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
				die "未知的 DNF 仓库类型: ${NAME} (允许 rpm/repo 文件)"
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
		die "没有调用 dnf_use_environment 就使用 DNF 环境"
	fi
	local -r WORKING_CONTAINER="$1" PACKAGE_FILE="$2" POST_SCRIPT="${3-}" DNF="${_DNF_ENVIRONMENT_CID}"

	local TMPSCRIPT ROOT

	if [[ ! -e ${PACKAGE_FILE} ]]; then
		die "缺失列表文件: ${PACKAGE_FILE}"
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
			die "缺失脚本文件: ${POST_SCRIPT}"
		fi
		local POST_SCRIPT_ABS
		POST_SCRIPT_ABS=$(realpath -e "${POST_SCRIPT}")
		CONTAINER_ARGS+=("--volume=${POST_SCRIPT_ABS}:/tmp/dnf.postscript.sh:ro")
	fi

	function _run_group() {
		local INSTALL_ROOT
		INSTALL_ROOT=$(buildah mount "${WORKING_CONTAINER}")
		info_note "工作目录物理位置: ${INSTALL_ROOT}"
		create_dnf_arguments CONTAINER_ARGS "${INSTALL_ROOT}"

		buildah run "${CONTAINER_ARGS[@]}" "${_DNF_ENVIRONMENT_CID}" \
			/usr/local/bin/dnf "${DNF_ARGS[@]}"

		buildah unmount "${WORKING_CONTAINER}"

		info_note "DNF 运行完成"
	}

	alternative_buffer_execute \
		"为镜像 ${WORKING_CONTAINER} 运行脚本: ${POST_SCRIPT}, 命令行: dnf ${DNF_ARGS[*]}" \
		_run_group
	unset -f _run_group
}

function call_dnf_without_guest() {
	if ! variable_bounded _DNF_ENVIRONMENT_CID; then
		die "没有调用 dnf_use_environment 就使用 DNF 环境"
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
		info_error "[dnf:${ERRNO}] 列出软件包版本失败"
		cat "${TMPF}"
		info_error "[dnf:${ERRNO}] 列出软件包版本失败"
		return 1
	fi
	RET=$(grep -v --fixed-strings i686 "${TMPF}" | grep --fixed-strings '.' | awk '{print $1 " = " $2}')
	info_log "================================================="
	indent_multiline "${RET}"
	info_log "================================================="

	control_ci summary "<details>
  <summary>DNF 安装</summary>

\`\`\`text
${RET}
\`\`\`
</details>
"

	echo "${RET}"
}

function dnf_install_step() {
	local CACHE_NAME="$1"
	local PKG_LIST_FILE="$2"
	local POST_SCRIPT="${3-}"

	if [[ ! -e ${PKG_LIST_FILE} ]]; then
		die "缺失安装列表文件: ${PKG_LIST_FILE}"
	fi
	if [[ -n ${POST_SCRIPT} && ! -e ${POST_SCRIPT} ]]; then
		die "缺失安装后脚本: ${POST_SCRIPT}"
	fi

	_dnf_hash_cb() {
		info_log "dnf 安装 (包列表: ${PKG_LIST_FILE})..."
		cat "${PKG_LIST_FILE}"
		info_note "   列出版本..."
		dnf_list_version "${PKG_LIST_FILE}"
		if [[ -n ${POST_SCRIPT} ]]; then cat "${POST_SCRIPT}"; fi
	}
	_dnf_build_cb() {
		local CONTAINER="$1"
		call_dnf_install "${CONTAINER}" "${PKG_LIST_FILE}" "${POST_SCRIPT}"
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
	die "禁止在主机上运行 DNF!"
}

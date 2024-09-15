function make_base_image_by_alpine_pip() {
	local BASEIMG=$1 NAME=$2 REQUIREMENTS_TXT=$3 BUILD_SYS_DEPS_FILE=$4 RT_SYS_DEPS_FILE=$5
	local USE_CACHE="--volume=${SYSTEM_COMMON_CACHE}/pip:/var/cache/pip"
	local BUILDAH_EXTRA_ARGS=("${USE_CACHE}")
	local PIP_CMD=(pip install --cache-dir /var/cache/pip --no-input -i https://pypi.tuna.tsinghua.edu.cn/simple)

	local EX_PKGS_BU=()
	if [[ -n ${BUILD_SYS_DEPS_FILE} ]]; then
		mapfile -t EX_PKGS_BU <"${BUILD_SYS_DEPS_FILE}"
	fi

	local PKGS_RT=()
	if [[ -n ${RT_SYS_DEPS_FILE} ]]; then
		mapfile -t PKGS_RT <"${RT_SYS_DEPS_FILE}"
	fi

	mkdir -p "${SYSTEM_COMMON_CACHE}/pip"

	STEP="安装python和系统依赖"
	echo "python3 -m ${PIP_CMD[*]} --upgrade pip ; python3 -m pip --version" \
		| deny_proxy make_base_image_by_apk "alpine" "${NAME}-build" python3 py3-pip "${EX_PKGS_BU[@]}"

	STEP="安装pip依赖"
	function _hash_() {
		# TODO: check versions
		cat "${REQUIREMENTS_TXT}"
	}
	function _build_() {
		buildah copy "$1" "${REQUIREMENTS_TXT}" "/tmp/requirements.txt"
		buildah run "$1" \
			python3 -m "${PIP_CMD[@]}" \
			--user -r /tmp/requirements.txt
	}
	deny_proxy buildah_cache "${NAME}-build" _hash_ _build_
	local PIP_SOURCE_IMAGE=${BUILDAH_LAST_IMAGE}

	unset -f _hash_ _build_
	unset BUILDAH_EXTRA_ARGS

	## make_base_image_by_apk
	STEP="安装运行时系统依赖"
	make_base_image_by_apk "${BASEIMG}" "${NAME}" "${PKGS_RT[@]}"

	STEP="复制pip安装结果"
	function _hash_() {
		echo "${PIP_SOURCE_IMAGE}"
	}
	function _build_() {
		buildah copy "--from=${PIP_SOURCE_IMAGE}" "$1" "/root/.local/lib" "/root/.local/lib"
		buildah run "$1" du -hs /root
	}
	buildah_cache "${NAME}" _hash_ _build_
	unset -f _hash_ _build_
}

function make_base_image_by_fedora_pip() {
	local NAME=$1 REQUIREMENTS_TXT=$2 BUILD_SYS_DEPS_FILE=$3 RT_SYS_DEPS_FILE=$4
	local USE_CACHE="--volume=${SYSTEM_COMMON_CACHE}/pip:/var/cache/pip"
	local BUILDAH_EXTRA_ARGS=("${USE_CACHE}")
	local PIP_CMD=(pip install --cache-dir /var/cache/pip --no-input -i https://pypi.tuna.tsinghua.edu.cn/simple)

	mkdir -p "${SYSTEM_COMMON_CACHE}/pip"

	local TMPLIST=$(create_temp_file) TMPSCRIPT=$(create_temp_file)
	echo python3 >"${TMPLIST}"
	echo python3-pip >>"${TMPLIST}"
	if [[ -n ${BUILD_SYS_DEPS_FILE} ]]; then
		cat "${BUILD_SYS_DEPS_FILE}" >>"${TMPLIST}"
	fi

	STEP="安装python和系统依赖"
	cat <<-EOF >"${TMPSCRIPT}"
		python3 -m "${PIP_CMD[@]}" --upgrade pip
		python3 -m pip --version
	EOF
	make_base_image_by_dnf "${NAME}-build" "${TMPLIST}" "${TMPSCRIPT}"

	STEP="安装pip依赖"
	function _hash_() {
		# TODO: check versions
		cat "${REQUIREMENTS_TXT}"
	}
	function _build_() {
		buildah copy "$1" "${REQUIREMENTS_TXT}" "/tmp/requirements.txt"
		buildah run "$1" \
			python3 -m "${PIP_CMD[@]}" \
			--user -r /tmp/requirements.txt
	}
	deny_proxy buildah_cache "${NAME}-build" _hash_ _build_
	local PIP_SOURCE_IMAGE=${BUILDAH_LAST_IMAGE}

	unset -f _hash_ _build_
	unset BUILDAH_EXTRA_ARGS

	## make_base_image_by_apk
	TMPLIST=$(create_temp_file)
	echo python3 >"${TMPLIST}"
	if [[ -n ${RT_SYS_DEPS_FILE} ]]; then
		cat "${RT_SYS_DEPS_FILE}" >>"${TMPLIST}"
	fi
	STEP="安装运行时系统依赖"
	perfer_proxy make_base_image_by_dnf "${NAME}" "${TMPLIST}"

	STEP="复制pip安装结果"
	function _hash_() {
		echo "${PIP_SOURCE_IMAGE}"
	}
	function _build_() {
		buildah copy "--from=${PIP_SOURCE_IMAGE}" "$1" "/root/.local/lib" "/root/.local/lib"
		buildah run "$1" du -hs /root
	}
	buildah_cache "${NAME}" _hash_ _build_
	unset -f _hash_ _build_
}

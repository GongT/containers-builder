#!/usr/bin/env bash

declare -xr GIT_REPO_EXPIRES=604800 # 7 days

function download_file_force() {
	local FILE="download_${RANDOM}" URL="$1"

	local EXT
	EXT=$(basename "${URL}")
	EXT="${EXT%%\?*}"
	EXT="${EXT#*.}"
	FILE+=".${EXT}"

	FORCE_DOWNLOAD=yes download_file "${URL}" "${FILE}"
}
function download_file() {
	local URL="$1" NAME="${2-}"
	if [[ -z ${NAME} ]]; then
		NAME=$(basename "${URL}")
	fi
	local OUTFILE="${PRIVATE_CACHE}/download/${NAME}"
	local ARGS=()

	if [[ -z ${URL} ]]; then
		die "缺失下载 URL"
	fi

	mkdir -p "${PRIVATE_CACHE}/download"
	if [[ -n ${CI-} ]]; then
		ARGS+=(--verbose)
	else
		ARGS+=(--progress=bar)
	fi
	if [[ ${FORCE_DOWNLOAD+found} == found ]] || ! [[ -e ${OUTFILE} ]]; then
		local EXARGS=('--continue')

		if [[ -n ${HTTP_COOKIE-} ]]; then
			EXARGS+=(--header "Cookie: ${HTTP_COOKIE}")
		fi

		control_ci group "download with wget"
		info " * 正在从 ${URL} 下载 ${NAME}"
		x wget "${EXARGS[@]}" "${ARGS[@]}" "${URL}" -O "${OUTFILE}.downloading" >&2

		mv "${OUTFILE}.downloading" "${OUTFILE}"
		info_log "    下载完成"
		control_ci groupEnd
	else
		info_log "文件 ${NAME} 有缓存，跳过下载"
	fi

	echo "${OUTFILE}"
}

function decompression_file_source() {
	local SRC_PROJECT_NAME=$1 COMPRESS_FILE=$2 STRIP=${3:-0}
	local RELPATH="${CURRENT_DIR}/source/${SRC_PROJECT_NAME}"
	if [[ -n ${CI-} ]] && [[ -e ${RELPATH} ]]; then
		rm -rf "${RELPATH}"
	fi
	if [[ ! -f "${CURRENT_DIR}/source/.gitignore" ]] || ! grep -q "^${SRC_PROJECT_NAME}$" "${CURRENT_DIR}/source/.gitignore"; then
		mkdir -p "${CURRENT_DIR}/source"
		echo "${SRC_PROJECT_NAME}" >>"${CURRENT_DIR}/source/.gitignore"
	fi
	decompression_file "${COMPRESS_FILE}" "${STRIP}" "${RELPATH}"
	echo "${RELPATH}"
}

function decompression_file() {
	local FILE="$1" STRIP="$2" TARGET="$3"
	info " * 正在解压 ${FILE}"
	case "${FILE}" in
	*.tar.gz | *.tar.xz | *.tar.bz2)
		extract_tar "$@"
		;;
	*.zip)
		extract_zip "$@"
		;;
	*)
		die "    解压缩失败！"
		;;
	esac
	info "    解压完成"
}

function extract_tar() {
	local FILE="$1" STRIP="${2}" TARGET="$3"

	mkdir -p "${TARGET}"
	info_log tar --strip-components="${STRIP}" -xf "${FILE}" -C "${TARGET}"
	tar --strip-components="${STRIP}" -xf "${FILE}" -C "${TARGET}"
}

function extract_zip() {
	local FILE="$1" TARGET="$3"
	local STRIP="${2}"
	local TDIR="${TARGET}/.extract"
	mkdir -p "${TDIR}"
	pushd "${TDIR}" &>/dev/null || die "系统调用错误 chdir"

	unzip -q -o -d . "${FILE}"

	local STRIPSTR=""
	while [[ ${STRIP} -gt 0 ]]; do
		STRIP=$((STRIP - 1))
		STRIPSTR+="*/"
	done
	STRIPSTR+="*"

	# shellcheck disable=SC2086
	mv -f ${STRIPSTR} -t "${TARGET}"

	popd &>/dev/null || die "系统调用错误 chdir"
}

function __github_api() {
	local URL="https://api.github.com/$*"
	local TOKEN_PARAM=()
	control_ci group "GitHub API调用: ${URL}"
	if [[ ${GITHUB_TOKEN+found} == found ]]; then
		TOKEN_PARAM=(--header "authorization: Bearer ${GITHUB_TOKEN}")
	else
		info_warn "GITHUB_TOKEN 未设置，可能会触发限制。"
	fi

	API_RESULT=$(perfer_proxy curl_proxy "${TOKEN_PARAM[@]}" --location -s "${URL}")
	echo "${API_RESULT}" >&2
	control_ci groupEnd

	echo "${API_RESULT}"
}

function http_get_github_tag_commit() {
	local REPO="$1"
	local URL="repos/${REPO}/tags"
	info_log " * 正在从 ${URL} 获取标签"
	__github_api "${URL}" | filtered_jq '.[0].commit.sha'
}

LAST_GITHUB_RELEASE_JSON=""
function http_get_github_release() {
	local REPO="$1"
	local URL="repos/${REPO}/releases/latest"
	info_log " * 正在从 ${URL} 获取发布信息"
	LAST_GITHUB_RELEASE_JSON=$(__github_api "${URL}")
}
function __github_release_json_id() {
	ID=$(echo "${LAST_GITHUB_RELEASE_JSON}" | filtered_jq '(.id|tostring) + " - " + .target_commitish')

	info_log "       发布 ID = ${ID}"
	if [[ -n ${ID} ]]; then
		echo "${ID}"
	else
		die "获取 ETag 失败"
	fi
}

function http_get_github_release_id() {
	local REPO="$1" ID
	http_get_github_release "${REPO}"
	__github_release_json_id
}

function github_release_asset_download_url() {
	local -r NAME="$1"
	local RESULT=
	# shellcheck disable=SC2016
	RESULT=$(echo "${LAST_GITHUB_RELEASE_JSON}" | filtered_jq '.assets[] | select(.name==$name) | .browser_download_url' --arg name "$1")

	if [[ -n ${RESULT} ]]; then
		echo "${RESULT}"
	else
		die "从头 GitHub Release 获取资产下载 URL 失败"
	fi
}
function github_release_asset_download_url_regex() {
	local -r NAME="$1"
	local RESULT=
	# shellcheck disable=SC2016
	RESULT=$(echo "${LAST_GITHUB_RELEASE_JSON}" | filtered_jq '.assets[] | select(.name|test($name; "i")) | .browser_download_url' --arg name "$1")

	if [[ -n ${RESULT} ]]; then
		echo "${RESULT}"
	else
		die "从头 GitHub Release 获取资产下载 URL 失败"
	fi
}

function http_get_github_last_commit_id() {
	local REPO=$1 API_RESULT
	info_log " * 正在检查 ${REPO} 的最新提交 ID"
	__github_api "repos/${REPO}/commits?per_page=1" | filtered_jq '.[0].sha'
}
function http_get_github_default_branch_name() {
	## todo: cache 1 day
	local REPO=$1 API_RESULT
	info_log " * 正在获取 ${REPO} 的默认分支名称"
	__github_api "repos/$1" | filtered_jq '.default_branch'
}
function http_get_github_last_commit_id_on_branch() {
	local REPO=$1 BRANCH=$2 RESULT
	info_log " * 正在检查 ${REPO} (${BRANCH}) 的最新提交 ID"
	RESULT=$(__github_api "repos/${REPO}/branches/${BRANCH}" | filtered_jq '.commit.sha')
	info_log "     = ${RESULT}"
	echo "${RESULT}"
}

function _join_git_path() {
	local NAME="$1" BRANCH="$2"
	echo "${PRIVATE_CACHE}/gitrepo/${NAME}-${BRANCH}"
}

function hash_git_result() {
	local NAME="$1" BRANCH="$2" WT
	printf '%s:%s>' "${NAME}" "${BRANCH}"
	WT="$(_join_git_path "${NAME}" "${BRANCH}")"
	git -C "${WT}" log --format="%H" -n 1
}

function download_github() {
	local REPO="$1" BRANCH="$2"
	perfer_proxy download_git "https://github.com/${REPO}.git" "$REPO" "$BRANCH"
}
function download_git() {
	local URL="$1" NAME="$2" BRANCH="$3" CWD
	declare -x GIT_DIR
	CWD="$(_join_git_path "${NAME}" "${BRANCH}")"
	GIT_DIR="${CWD}/.git"

	local -r TIMESTAMP="${GIT_DIR}/timestamp"

	info "运行 git 克隆 ${URL} (分支: ${BRANCH})"
	indent
	info_log "本地目录 ${CWD}"

	if [[ -e "${GIT_DIR}/config" ]]; then
		local REFS
		mapfile -t REFS < <(git -C "${CWD}" for-each-ref "--format=%(refname)" refs/heads/ || true)
		if [[ ${#REFS[@]} != 1 ]] || [[ ${REFS[0]} != "refs/heads/${BRANCH}" ]]; then
			info_warn "无效的 git 状态: 多个或无效的分支"
			rm -rf "${CWD}"
		fi
	fi

	if [[ -e "${GIT_DIR}/config" ]]; then
		local CTIME
		CTIME=$(date +%s)
		if [[ -e ${TIMESTAMP} ]] && [[ $(<"${TIMESTAMP}") -gt $((CTIME - GIT_REPO_EXPIRES)) ]]; then
			CTIME=$(<"${TIMESTAMP}")
			CTIME=$((CTIME + GIT_REPO_EXPIRES))
			info_success "跳过下载, 缓存过期时间 $(date "--date=@${CTIME}" +"%F %T")"
		else
			info "更新现有缓存"
			indent_stream retry_execute 10 3 git -C "${CWD}" submodule update --depth 3 --recursive
			indent_stream x git -C "${CWD}" submodule sync --recursive
			indent_stream retry_execute 10 3 git -C "${CWD}" submodule update --depth 3 --init --recursive
			indent_stream retry_execute 10 3 git -C "${CWD}" fetch --depth=3 --no-tags --update-shallow --recurse-submodules
			indent_stream x git -C "${CWD}" reset --hard "origin/${BRANCH}"

			date +%s >"${TIMESTAMP}"

			info_success "更新完成"
		fi
	else
		info "克隆新仓库"
		if [[ -d ${CWD} ]]; then
			info_warn "删除文件夹: ${CWD}"
			rm -rf "${CWD}"
		fi
		mkdir -p "${CWD}"

		indent_stream retry_execute 10 3 git -C "${CWD}" clone --depth 3 --no-tags --recurse-submodules --shallow-submodules --branch "${BRANCH}" --single-branch "${URL}" . 2>&1

		date +%s >"${TIMESTAMP}"
		info_success "克隆完成"
	fi

	info_bright "最后提交 ID 是: $(git -C "${CWD}" log --format="%H" -n 1)"
	dedent
	unset GIT_DIR
}
function download_git_result_copy() {
	local DIST="$1" NAME=$2 BRANCH="${3}" CWD
	declare -x GIT_DIR
	CWD="$(_join_git_path "${NAME}" "${BRANCH}")"
	GIT_DIR="${CWD}/.git"

	if [[ ! -f "${GIT_DIR}/timestamp" ]]; then
		die "缺失下载的 git 数据: ${GIT_DIR} (来自 ${NAME})"
	fi
	# DIST="$SYSTEM_FAST_CACHE/git-temp/$(echo "$GIT_DIR" | md5sum | awk '{print $1}')"
	mkdir -p "${DIST}"
	x git -C "${DIST}" "--git-dir=${GIT_DIR}" checkout --recurse-submodules "${BRANCH}" -- .
	# git clone --depth 1 --recurse-submodules --shallow-submodules --single-branch "file://$GIT_DIR" "$DIST"
	unset GIT_DIR
}

declare LAST_HTTP_HEADER_RESULT=
function http_get_headers() {
	local URL="$1"
	info_log "  * 获取 HTTP 头: ${URL}"
	echo -ne "\e[2m" >&2
	LAST_HTTP_HEADER_RESULT=$(curl_proxy -I --retry 5 --location "${URL}")
	echo -ne "\e[0m" >&2
	echo "${LAST_HTTP_HEADER_RESULT}"
}

function http_header_get_one() {
	http_header_get_multiple "$@" | tail -n1
}
function http_header_get_multiple() {
	local NAME=$1 KEY
	local -i LEN"=${#NAME}+2"
	echo "${LAST_HTTP_HEADER_RESULT}" | while read -r LINE; do
		KEY=${LINE:0:LEN}
		if [[ ${KEY^^} != "${NAME^^}: " ]]; then
			continue
		fi

		echo "${LINE:LEN}" | tr -d '\r'
	done
}

function http_get_etag() {
	local URL="$1" ETAG
	info_log "  * 获取 ETag: ${URL}"
	echo -ne "\e[2m" >&2
	ETAG=$(curl_proxy -I --retry 5 --location "${URL}" | grep -iE '^ETag: ' | sed -E 's/ETag: "(.+)"/\1/ig' | sed 's/\r//g')
	echo -ne "\e[0m" >&2
	info_log "       = ${ETAG}"
	if [[ -n ${ETAG} ]]; then
		echo "${ETAG}"
	else
		die "获取 ETag 失败"
	fi
}

function curl_proxy() {
	local PROXY_VAL=()
	if [[ -n ${HTTP_PROXY-} ]]; then
		PROXY_VAL=(--proxy "${HTTP_PROXY}")
	fi
	info_note "    + 运行 curl: ${PROXY_VAL[*]} $*"
	curl "${PROXY_VAL[@]}" "$@"
}

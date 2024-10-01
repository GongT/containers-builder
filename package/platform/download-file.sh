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
		die "missing download url."
	fi

	mkdir -p "${PRIVATE_CACHE}/download"
	if [[ -n ${CI-} ]]; then
		ARGS+=(--verbose)
	else
		ARGS+=(--progress=bar)
	fi
	if [[ ${FORCE_DOWNLOAD+found} == found ]] || ! [[ -e ${OUTFILE} ]]; then
		local EXARGS=()

		if [[ -n ${HTTP_COOKIE-} ]]; then
			EXARGS+=(--header "Cookie: ${HTTP_COOKIE}")
		fi

		control_ci group "download with wget"
		info " * downloading ${NAME} from ${URL}"
		x wget "${EXARGS[@]}" "${URL}" -O "${OUTFILE}.downloading" "${ARGS[@]}" --tries=8 --continue >&2

		mv "${OUTFILE}.downloading" "${OUTFILE}"
		info_log "    downloaded."
		control_ci groupEnd
	else
		info_log "download file ${NAME} cached."
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
	info " * extracting ${FILE}"
	case "${FILE}" in
	*.tar.gz | *.tar.xz | *.tar.bz2)
		extract_tar "$@"
		;;
	*.zip)
		extract_zip "$@"
		;;
	*)
		die "Unable to extract ${FILE}"
		;;
	esac
	info "    extracted."
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
	pushd "${TDIR}" &>/dev/null || die "error syscall chdir"

	unzip -q -o -d . "${FILE}"

	local STRIPSTR=""
	while [[ ${STRIP} -gt 0 ]]; do
		STRIP=$((STRIP - 1))
		STRIPSTR+="*/"
	done
	STRIPSTR+="*"

	# shellcheck disable=SC2086
	mv -f ${STRIPSTR} -t "${TARGET}"

	popd &>/dev/null || die "error syscall chdir"
}

function __github_api() {
	local URL="https://api.github.com/$*"
	local TOKEN_PARAM=()
	if [[ ${GITHUB_TOKEN+found} == found ]]; then
		TOKEN_PARAM=(--header "authorization: Bearer ${GITHUB_TOKEN}")
	fi

	control_ci group "Github Api: ${URL}"
	API_RESULT=$(perfer_proxy curl_proxy "${TOKEN_PARAM[@]}" --location -s "${URL}")
	echo "${API_RESULT}" >&2
	control_ci groupEnd

	echo "${API_RESULT}"
}

function http_get_github_tag_commit() {
	local REPO="$1"
	local URL="repos/${REPO}/tags"
	info_log " * fetching tags from ${URL}"
	__github_api "${URL}" | filtered_jq '.[0].commit.sha'
}

LAST_GITHUB_RELEASE_JSON=""
function http_get_github_release() {
	local REPO="$1"
	local URL="repos/${REPO}/releases/latest"
	info_log " * fetching release from ${URL}"
	LAST_GITHUB_RELEASE_JSON=$(__github_api "${URL}")
}
function __github_release_json_id() {
	ID=$(echo "${LAST_GITHUB_RELEASE_JSON}" | filtered_jq '(.id|tostring) + " - " + .target_commitish')

	info_log "       release id = ${ID}"
	if [[ -n ${ID} ]]; then
		echo "${ID}"
	else
		die "failed get ETag"
	fi
}

function http_get_github_release_id() {
	local REPO="$1" ID
	http_get_github_release "${REPO}"
	__github_release_json_id
}

# latest always first, this not work
# function http_get_github_unstable_release() {
# 	local REPO="$1"
# 	local URL="repos/${REPO}/releases?per_page=1"
# 	info_log " * fetching UNSTABLE release from ${URL}"
# 	LAST_GITHUB_RELEASE_JSON=$(__github_api "${URL}" | filtered_jq '.[0]')
# }
#
# function http_get_github_unstable_release_id() {
# 	local REPO="$1" ID
# 	http_get_github_unstable_release "${REPO}"
# 	__github_release_json_id
# }

function github_release_asset_download_url() {
	local -r NAME="$1"
	local RESULT=
	# shellcheck disable=SC2016
	RESULT=$(echo "${LAST_GITHUB_RELEASE_JSON}" | filtered_jq '.assets[] | select(.name==$name) | .browser_download_url' --arg name "$1")

	if [[ -n ${RESULT} ]]; then
		echo "${RESULT}"
	else
		die "failed get asset download url"
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
		die "failed get asset download url"
	fi
}

function http_get_github_last_commit_id() {
	local REPO=$1 API_RESULT
	info_log " * check last commit id of ${REPO}"
	__github_api "repos/${REPO}/commits?per_page=1" | filtered_jq '.[0].sha'
}
function http_get_github_default_branch_name() {
	## todo: cache 1 day
	local REPO=$1 API_RESULT
	info_log " * fetching default branch name ${REPO}"
	__github_api "repos/$1" | filtered_jq '.default_branch'
}
function http_get_github_last_commit_id_on_branch() {
	local REPO=$1 BRANCH=$2 RESULT
	info_log " * check last commit id of ${REPO} (${BRANCH})"
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

	info "git clone ${URL} (${BRANCH})"
	indent
	info_log "   to ${CWD}"

	if [[ -e "${GIT_DIR}/config" ]]; then
		local REFS
		mapfile -t REFS < <(git -C "${CWD}" for-each-ref "--format=%(refname)" refs/heads/ || true)
		if [[ ${#REFS[@]} != 1 ]] || [[ ${REFS[0]} != "refs/heads/${BRANCH}" ]]; then
			info_warn "invalid git status: multiple or invalid branch"
			rm -rf "${CWD}"
		fi
	fi

	if [[ -e "${GIT_DIR}/config" ]]; then
		local CTIME
		CTIME=$(date +%s)
		if [[ -e ${TIMESTAMP} ]] && [[ $(<"${TIMESTAMP}") -gt $((CTIME - GIT_REPO_EXPIRES)) ]]; then
			CTIME=$(<"${TIMESTAMP}")
			CTIME=$((CTIME + GIT_REPO_EXPIRES))
			info_success "skip download, cache expire at $(date "--date=@${CTIME}" +"%F %T")"
		else
			info "update existing cache."
			indent_stream retry_execute 10 3 git -C "${CWD}" submodule update --depth 3 --recursive
			indent_stream x git -C "${CWD}" submodule sync --recursive
			indent_stream retry_execute 10 3 git -C "${CWD}" submodule update --depth 3 --init --recursive
			indent_stream retry_execute 10 3 git -C "${CWD}" fetch --depth=3 --no-tags --update-shallow --recurse-submodules
			indent_stream x git -C "${CWD}" reset --hard "origin/${BRANCH}"

			date +%s >"${TIMESTAMP}"

			info_success "update complete."
		fi
	else
		info "clone new repo."
		if [[ -d ${CWD} ]]; then
			info_warn "deleting folder: ${CWD}"
			rm -rf "${CWD}"
		fi
		mkdir -p "${CWD}"

		indent_stream retry_execute 10 3 git -C "${CWD}" clone --depth 3 --no-tags --recurse-submodules --shallow-submodules --branch "${BRANCH}" --single-branch "${URL}" . 2>&1

		date +%s >"${TIMESTAMP}"
		info_success "clone complete."
	fi

	info_bright "last commit id is: $(git -C "${CWD}" log --format="%H" -n 1)"
	dedent
	unset GIT_DIR
}
function download_git_result_copy() {
	local DIST="$1" NAME=$2 BRANCH="${3}" CWD
	declare -x GIT_DIR
	CWD="$(_join_git_path "${NAME}" "${BRANCH}")"
	GIT_DIR="${CWD}/.git"

	if [[ ! -f "${GIT_DIR}/timestamp" ]]; then
		die "missing downloaded git data: ${GIT_DIR} (from ${NAME})"
	fi
	# DIST="$SYSTEM_FAST_CACHE/git-temp/$(echo "$GIT_DIR" | md5sum | awk '{print $1}')"
	mkdir -p "${DIST}"
	x git -C "${DIST}" "--git-dir=${GIT_DIR}" checkout --recurse-submodules "${BRANCH}" -- .
	# git clone --depth 1 --recurse-submodules --shallow-submodules --single-branch "file://$GIT_DIR" "$DIST"
	unset GIT_DIR
}

function http_get_etag() {
	local URL="$1" ETAG
	info_log " * fetching ETag: ${URL}"
	echo -ne "\e[2m" >&2
	ETAG=$(curl_proxy -I --retry 5 --location "${URL}" | grep -iE '^ETag: ' | sed -E 's/ETag: "(.+)"/\1/ig' | sed 's/\r//g')
	echo -ne "\e[0m" >&2
	info_log "       = ${ETAG}"
	if [[ -n ${ETAG} ]]; then
		echo "${ETAG}"
	else
		die "failed get ETag"
	fi
}

function curl_proxy() {
	local PROXY_VAL=()
	if [[ -n ${HTTP_PROXY-} ]]; then
		PROXY_VAL=(--proxy "${HTTP_PROXY}")
	fi
	info_note "    + curl ${PROXY_VAL[*]} $*"
	curl "${PROXY_VAL[@]}" "$@"
}

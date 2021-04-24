#!/usr/bin/env bash

declare -r LOCAL_TMP="$SYSTEM_COMMON_CACHE/Download"

function download_file_force() {
	local FILE="download_$RANDOM" URL="$1"
	FORCE_DOWNLOAD=yes download_file "$URL" "$FILE"
}
function download_file() {
	local URL="$1" NAME="$2"
	local OUTFILE="$LOCAL_TMP/$NAME"
	local ARGS=()

	info " * downloading $NAME ..."
	mkdir -p "$LOCAL_TMP"
	if [[ "${CI:-}" ]]; then
		ARGS+=(--verbose)
	else
		ARGS+=(--quiet --show-progress --progress=bar:force:noscroll)
	fi
	if [[ ${FORCE_DOWNLOAD+found} == found ]] || ! [[ -e $OUTFILE ]]; then
		local -i TRY=0
		local EXARGS=()

		if [[ ! ${HTTP_PROXY:-} ]]; then
			EXARGS+=(--no-proxy)
		fi

		while ! wget "${EXARGS[@]}" "${URL}" -O "${OUTFILE}.downloading" "${ARGS[@]}" --tries=0 --continue >&2; do
			TRY=$((TRY + 1))
			if [[ $TRY -gt 5 ]]; then
				rm -f "${OUTFILE}.downloading"
				die "Cannot download from $URL (after 5 try)"
			fi
			info_warn "Download failed, retry ($TRY)..."
		done
		mv "${OUTFILE}.downloading" "${OUTFILE}"
		info_log "    downloaded."
	else
		info_log "    download file cached."
	fi

	echo "$OUTFILE"
}

function decompression_file_source() {
	local SRC_PROJECT_NAME=$1 COMPRESS_FILE=$2 STRIP=${3:-0}
	local RELPATH="$CURRENT_DIR/source/$SRC_PROJECT_NAME"
	if [[ "${CI:-}" ]] && [[ -e $RELPATH ]]; then
		rm -rf "$RELPATH"
	fi
	if ! [[ -f "$CURRENT_DIR/source/.gitignore" ]] || ! grep -q "^$SRC_PROJECT_NAME$" "$CURRENT_DIR/source/.gitignore"; then
		mkdir -p "$CURRENT_DIR/source"
		echo "$SRC_PROJECT_NAME" >>"$CURRENT_DIR/source/.gitignore"
	fi
	decompression_file "$COMPRESS_FILE" "$STRIP" "$RELPATH"
	echo "$RELPATH"
}

function decompression_file() {
	local FILE="$1" STRIP="$2" TARGET="$3"
	info " * extracting $FILE ..."
	case "$FILE" in
	*.tar.gz | *.tar.xz | *.tar.bz2)
		extract_tar "$@"
		;;
	*.zip)
		extract_zip "$@"
		;;
	*)
		die "Unable to extract $FILE"
		;;
	esac
	info "    extracted."
}

function extract_tar() {
	local FILE="$1" STRIP="${2}" TARGET="$3"

	mkdir -p "$TARGET"
	info_log tar --strip-components="${STRIP}" -xf "$FILE" -C "$TARGET"
	tar --strip-components="${STRIP}" -xf "$FILE" -C "$TARGET"
}

function extract_zip() {
	local FILE="$1" TARGET="$3"
	local -I STRIP="${2}"
	local TDIR="$TARGET/.extract"
	mkdir -p "$TDIR"
	pushd "$TDIR" &>/dev/null || die "error syscall chdir"

	unzip -q -o -d . "$FILE"

	local STRIPSTR=""
	while [[ $STRIP -gt 0 ]]; do
		STRIP="$STRIP - 1"
		STRIPSTR+="*/"
	done
	STRIPSTR+="*"

	mv -f $STRIPSTR -t "$TARGET"

	popd &>/dev/null || die "error syscall chdir"
}

function __github_api() {
	local URL="https://api.github.com/$*"
	local TOKEN_PARAM=()
	if [[ ${GITHUB_TOKEN+found} == found ]]; then
		TOKEN_PARAM=(--header "authorization: Bearer ${GITHUB_TOKEN}")
	fi
	curl_proxy "${TOKEN_PARAM[@]}" -s "$URL"
}

LAST_GITHUB_RELEASE_JSON=""
function http_get_github_release_id() {
	local REPO="$1" ID
	local URL="repos/$REPO/releases/latest"
	info_log " * fetching release id (+commit hash) from $URL ... "

	LAST_GITHUB_RELEASE_JSON=$(__github_api "$URL")
	ID=$(echo "$LAST_GITHUB_RELEASE_JSON" | jq -r '(.id|tostring) + "-" + .target_commitish')

	info_log "       = $ID"
	if [[ "$ID" ]]; then
		echo "$ID"
	else
		die "failed get ETag"
	fi
}

function http_get_github_last_commit_id() {
	__github_api "/repos/$1/commits?per_page=1" | jq -r '.id'
}
function http_get_github_default_branch_name() {
	__github_api "/repos/$1" | jq -r '.default_branch'
}
function http_get_github_last_commit_id_on_branch() {
	if [[ $# -gt 1 ]]; then
		__github_api "/repos/$1/branches/$2" | jq -r '.commit.sha'
	else
		local B
		B=$(http_get_github_default_branch_name "$1")
		http_get_github_last_commit_id_on_branch "$1" "$B"
	fi
}

function _download_git_result() {
	local NAME="$1" BRANCH_TAG="${3:-default}"
	echo "$LOCAL_TMP/$NAME-${BRANCH_TAG}"
}
function download_github() {
	local REPO="$1"
	download_git "https://github.com/$REPO.git" "$@"
}
function download_git() {
	local URL="$1" NAME="$2" BRANCH="${3:-}" BRANCH_TAG="${3:-default}" GIT_DIR
	GIT_DIR="$(_download_git_result "$NAME" "$BRANCH_TAG")"
	mkdir -p "$GIT_DIR"

	info " * git clone $URL ..."
	info_note "      to $GIT_DIR ..."
	if [[ -e "$GIT_DIR/config" ]]; then
		local -i BNUM
		BNUM=$(git "--git-dir=$GIT_DIR" branch | wc -l)
		if [[ $BNUM != 1 ]]; then
			info_warn "invalid git status: multiple branch"
			rm -rf "$GIT_DIR"
			download_git "$@"
			return
		fi
		x git "--git-dir=$GIT_DIR" fetch --depth=1
	else
		local BARG=()
		if [[ "$BRANCH" ]]; then
			BARG=(--branch "$BRANCH")
		fi
		x git clone --bare --depth 5 "${BARG[@]}" --single-branch "$URL" "$GIT_DIR"
	fi
}
function download_git_result_copy() {
	local NAME=$2 BRANCH_TAG="${3:-default}" GIT_DIR DIST="$1"
	GIT_DIR=$(_download_git_result "$NAME" "$BRANCH_TAG")
	if ! [[ -f "$GIT_DIR/config" ]]; then
		die "missing downloaded git data: $GIT_DIR (from $NAME)"
	fi
	# DIST="$SYSTEM_FAST_CACHE/git-temp/$(echo "$GIT_DIR" | md5sum | awk '{print $1}')"
	x git clone --depth 1 --single-branch "file://$GIT_DIR" "$DIST"
	rm -rf "$DIST/.git"
}

function http_get_etag() {
	local URL="$1" ETAG
	info_log " * fetching ETag ..."
	echo -ne "\e[2m" >&2
	ETAG=$(curl_proxy -I --retry 5 --location "$URL" | grep -iE '^ETag: ' | sed -E 's/ETag: "(.+)"/\1/ig' | sed 's/\r//g')
	echo -ne "\e[0m" >&2
	info_log "       = $ETAG"
	if [[ "$ETAG" ]]; then
		echo "$ETAG"
	else
		die "failed get ETag"
	fi
}

function curl_proxy() {
	local PROXY_VAL=()
	if [[ "${HTTP_PROXY:-}" ]]; then
		PROXY_VAL=(--proxy "$HTTP_PROXY")
	fi
	info_note "    + curl ${PROXY_VAL[*]} $*"
	curl "${PROXY_VAL[@]}" "$@"
}

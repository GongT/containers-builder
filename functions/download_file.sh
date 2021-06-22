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

	info " * downloading $NAME from $URL"
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

		control_ci group "download with wget"
		while ! wget "${EXARGS[@]}" "${URL}" -O "${OUTFILE}.downloading" "${ARGS[@]}" --tries=0 --continue >&2; do
			TRY=$((TRY + 1))
			if [[ $TRY -gt 5 ]]; then
				rm -f "${OUTFILE}.downloading"
				die "Cannot download from $URL (after 5 try)"
			fi
			info_warn "Download failed, retry ($TRY)..."
		done
		control_ci groupEnd

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
	info " * extracting $FILE"
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

	control_ci group "Github Api: $URL"
	API_RESULT=$(perfer_proxy curl_proxy "${TOKEN_PARAM[@]}" -s "$URL")
	echo "$API_RESULT" >&2
	control_ci groupEnd

	echo "$API_RESULT"
}

LAST_GITHUB_RELEASE_JSON=""
function http_get_github_release_id() {
	local REPO="$1" ID
	local URL="repos/$REPO/releases/latest"
	info_log " * fetching release id (+commit hash) from $URL"

	LAST_GITHUB_RELEASE_JSON=$(__github_api "$URL")
	ID=$(echo "$LAST_GITHUB_RELEASE_JSON" | filtered_jq '(.id|tostring) + "-" + .target_commitish')

	info_log "       = $ID"
	if [[ "$ID" ]]; then
		echo "$ID"
	else
		die "failed get ETag"
	fi
}

function http_get_github_last_commit_id() {
	local REPO=$1 API_RESULT
	info_log " * check last commit id of $REPO"
	__github_api "repos/$REPO/commits?per_page=1" | filtered_jq '.[0].sha'
}
function http_get_github_default_branch_name() {
	## todo: cache 1 day
	local REPO=$1 API_RESULT
	info_log " * fetching default branch name $REPO"
	__github_api "repos/$1" | filtered_jq '.default_branch'
}
function http_get_github_last_commit_id_on_branch() {
	local REPO=$1 BRANCH=$2 RESULT
	info_log " * check last commit id of $REPO ($BRANCH)"
	RESULT=$(__github_api "repos/$REPO/branches/$BRANCH" | filtered_jq '.commit.sha')
	info_log "     = $RESULT"
	echo "$RESULT"
}

function _join_git_path() {
	local NAME="$1" BRANCH="$2"
	echo "$LOCAL_TMP/$NAME-$BRANCH"
}
function download_github() {
	local REPO="$1" BRANCH="$2" LAST_COMMIT CURRENT_COMMIT GIT_DIR
	GIT_DIR="$(_join_git_path "$REPO" "$BRANCH")"
	export GIT_DIR

	info " * github clone $REPO($BRANCH)"
	indent
	info_log "to $GIT_DIR"

	LAST_COMMIT=$(http_get_github_last_commit_id_on_branch "$REPO" "$BRANCH")

	if [[ -e "$GIT_DIR/config" ]]; then
		CURRENT_COMMIT=$(git log --format="%H" -n 1)
		info_log "local cache last commit is $(git log --format="[%h] '%s' (%cr)" -n 1)"

		if [[ $CURRENT_COMMIT == "$LAST_COMMIT" ]]; then
			info_log "no update detected"
			dedent
			echo "$LAST_COMMIT"
			return
		fi
	else
		info_log "no local cache"
	fi

	MUTE=yes perfer_proxy download_git "https://github.com/$REPO.git" "$@"
	dedent
}
function download_git() {
	local URL="$1" NAME="$2" BRANCH="$3"
	GIT_DIR="$(_join_git_path "$NAME" "$BRANCH")"
	export GIT_DIR
	mkdir -p "$GIT_DIR"

	[[ "${MUTE:-}" ]] || info " * git clone $URL"
	[[ "${MUTE:-}" ]] || info_note "      to $GIT_DIR"
	if [[ -e "$GIT_DIR/config" ]]; then
		local REFS
		mapfile -t REFS < <(git for-each-ref "--format=%(refname)" refs/heads/ || true)
		if [[ ${#REFS[@]} != 1 ]] || [[ ${REFS[0]} != "refs/heads/$BRANCH" ]]; then
			info_warn "invalid git status: multiple or invalid branch"
			rm -rf "$GIT_DIR"
			download_git "$@"
			return
		fi
		x git fetch --depth=5 --update-shallow --recurse-submodules
	else
		x git clone --bare --depth 5 --recurse-submodules --shallow-submodules --branch "$BRANCH" --single-branch "$URL" "$GIT_DIR"
	fi

	git log --format="%H" -n 1
	unset GIT_DIR
}
function download_git_result_copy() {
	local NAME=$2 BRANCH_TAG="${3:-default}" GIT_DIR DIST="$1"
	GIT_DIR=$(_join_git_path "$NAME" "$BRANCH_TAG")
	if ! [[ -f "$GIT_DIR/config" ]]; then
		die "missing downloaded git data: $GIT_DIR (from $NAME)"
	fi
	# DIST="$SYSTEM_FAST_CACHE/git-temp/$(echo "$GIT_DIR" | md5sum | awk '{print $1}')"
	x git clone --depth 1 --recurse-submodules --shallow-submodules --single-branch "file://$GIT_DIR" "$DIST"
	rm -rf "$DIST/.git"
}

function http_get_etag() {
	local URL="$1" ETAG
	info_log " * fetching ETag: $URL"
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

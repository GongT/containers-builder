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
		while ! wget "${URL}" -O "${OUTFILE}.downloading" "${ARGS[@]}" --tries=0 --continue >&2; do
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
	curl "${TOKEN_PARAM[@]}" -s "$URL"
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

function http_get_etag() {
	local URL="$1" ETAG
	info_log " * fetching ETag from $URL ... "
	echo -ne "\e[2m" >&2
	ETAG=$(curl -I --retry 5 --location "$URL" | grep -iE '^ETag: ' | sed -E 's/ETag: "(.+)"/\1/ig' | sed 's/\r//g')
	echo -ne "\e[0m" >&2
	info_log "       = $ETAG"
	if [[ "$ETAG" ]]; then
		echo "$ETAG"
	else
		die "failed get ETag"
	fi
}

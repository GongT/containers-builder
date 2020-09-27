declare -r LOCAL_TMP="$MONO_ROOT_DIR/.download"

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
	if [[ "${FORCE_DOWNLOAD+found}" == found ]] || ! [[ -e "$OUTFILE" ]]; then
		wget "${URL}" \
			-O "${OUTFILE}.downloading" \
			"${ARGS[@]}" --continue >&2 \
			|| die "Cannot download from $URL"
		mv "${OUTFILE}.downloading" "${OUTFILE}"
		info_log "    downloaded."
	else
		info_log "    download file cached."
	fi

	echo "$OUTFILE"
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
	info_log tar --strip-components="${STRIP-0}" -xf "$FILE" -C "$TARGET"
	tar --strip-components="${STRIP-0}" -xf "$FILE" -C "$TARGET"
}

function extract_zip() {
	local FILE="$1" TARGET="$3"
	local -I STRIP="${2}"
	local TDIR="$TARGET/.extract"
	mkdir -p "$TDIR"
	pushd "$TDIR" &> /dev/null

	unzip -q -o -d . "$FILE"

	local STRIPSTR=""
	while [[ "$STRIP" -gt 0 ]]; do
		STRIP="$STRIP - 1"
		STRIPSTR+="*/"
	done
	STRIPSTR+="*"

	mv -f $STRIPSTR -t "$TARGET"

	popd &> /dev/null
}

function http_get_etag() {
	local URL="$1" ETAG
	info_log " * fetching ETag from $URL... "
	echo -ne "\e[2m" >&2
	ETAG=$(curl -I --http1.1 --retry 3 --location "$URL" | grep -E '^ETag: ' | sed -E 's/ETag: "(.+)"/\1/g' | sed 's/\r//g')
	echo -ne "\e[0m" >&2
	info_log "       = $ETAG"
	if [[ "$ETAG" ]]; then
		echo "$ETAG"
	else
		die "failed get ETag"
	fi
}

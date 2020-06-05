declare -r LOCAL_TMP="$MONO_ROOT_DIR/.download"

function download_file() {
	local URL="$1" NAME="$2"
	local OUTFILE="$LOCAL_TMP/$NAME"

	if ! [[ -e "$OUTFILE" ]]; then
		mkdir -p "$LOCAL_TMP"
		info " * downloading $NAME ..."
		wget "${URL}" \
			-O "${OUTFILE}.downloading" \
			--quiet --continue --show-progress --progress=bar:force:noscroll >&2 \
			|| die "Cannot download from dl.google"
		mv "${OUTFILE}.downloading" "${OUTFILE}"
	fi
	info "    downloaded."

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

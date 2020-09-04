declare -A _CURRENT_STAGE_STORE=()
declare -r BUILDAH_CACHE_BASE=cache.example.com

# buildah_cache "$PREVIOUS_ID" hash_function build_function
# build_function <RESULT_CONTAINER_NAME>
function buildah_cache() {
	local -r BUILDAH_NAME_BASE=$1

	# no arg callback
	local -r BUILDAH_HASH_CALLBACK=$2

	# arg1=working container name [must create container this name]
	local -r BUILDAH_BUILD_CALLBACK=$3

	if [[ "${_CURRENT_STAGE_STORE[$BUILDAH_NAME_BASE]+found}" = 'found' ]]; then
		local -ir CURRENT_STAGE="${_CURRENT_STAGE_STORE[$BUILDAH_NAME_BASE]}"
		local -ir NEXT_STAGE="${CURRENT_STAGE} + 1"
	else
		local -ir CURRENT_STAGE=0
		local -ir NEXT_STAGE=1
	fi
	_CURRENT_STAGE_STORE[$BUILDAH_NAME_BASE]="$NEXT_STAGE"

	info_note "[$BUILDAH_NAME_BASE] STEP $NEXT_STAGE:"
	indent

	local -r BUILDAH_FROM="$BUILDAH_CACHE_BASE/$BUILDAH_NAME_BASE:stage-$CURRENT_STAGE"
	if [[ $CURRENT_STAGE -gt 0 ]]; then
		if ! image_exists "$BUILDAH_FROM"; then
			die "required previous stage [$BUILDAH_FROM] did not exists"
		fi
		local -r PREVIOUS_ID=$(buildah inspect --type image --format '{{.FromImageID}}' "$BUILDAH_FROM")
	else
		local -r PREVIOUS_ID="none"
	fi
	local -r BUILDAH_TO="$BUILDAH_CACHE_BASE/$BUILDAH_NAME_BASE:stage-$NEXT_STAGE"
	local -r WANTED_HASH=$("$BUILDAH_HASH_CALLBACK" | awk '{print $1}')

	if [[ "${BUILDAH_FORCE-no}" = "yes" ]]; then
		info_note "cache skip <BUILDAH_FORCE=yes>"
	elif image_exists "$BUILDAH_TO"; then
		local -r EXISTS_PREVIOUS_ID="$(builah_get_annotation "$BUILDAH_TO" "$ANNOID_CACHE_PREV_STAGE")"
		local -r EXISTS_HASH="$(builah_get_annotation "$BUILDAH_TO" "$ANNOID_CACHE_HASH")"
		info_note "cache exists <hash=$EXISTS_HASH, base=$EXISTS_PREVIOUS_ID>"
		if [[ "$EXISTS_HASH++$EXISTS_PREVIOUS_ID" = "$WANTED_HASH++$PREVIOUS_ID" ]]; then
			BUILDAH_LAST_IMAGE=$(buildah inspect --type image --format '{{.FromImageID}}' "$BUILDAH_TO")
			dedent
			info_note "[$BUILDAH_NAME_BASE] STEP $NEXT_STAGE DONE"
			return
		fi
		info_note "cache outdat <want=$WANTED_HASH, base=$PREVIOUS_ID>"
	else
		info_note "cache not exists"
	fi

	local -r CONTAINER_ID="${BUILDAH_NAME_BASE}_from${CURRENT_STAGE}_to${NEXT_STAGE}"
	"$BUILDAH_BUILD_CALLBACK" "$CONTAINER_ID"
	info_note "build callback finish"

	if ! container_exists "$CONTAINER_ID"; then
		die "BUILDAH_BUILD_CALLBACK<$BUILDAH_BUILD_CALLBACK> did not create $CONTAINER_ID."
	fi

	buildah config --add-history \
		--annotation "$ANNOID_CACHE_HASH=$WANTED_HASH" \
		--annotation "$ANNOID_CACHE_PREV_STAGE=$PREVIOUS_ID" \
		"$CONTAINER_ID" > /dev/null
	info_note "commit"
	BUILDAH_LAST_IMAGE=$(xbuildah commit --rm "$CONTAINER_ID" "$BUILDAH_TO")
	info_note "$BUILDAH_LAST_IMAGE"

	dedent
	info_note "[$BUILDAH_NAME_BASE] STEP $NEXT_STAGE DONE"
}

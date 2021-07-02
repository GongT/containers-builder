#!/usr/bin/env bash

declare -A _CURRENT_STAGE_STORE=()
declare -r BUILDAH_CACHE_BASE="${DOCKER_CACHE_CENTER:-cache.example.com/gongt/cache}"
declare LAST_CACHE_COMES_FROM=build # or pull

# buildah_cache "$PREVIOUS_ID" hash_function build_function
# build_function <RESULT_CONTAINER_NAME>
function buildah_cache() {
	local _STITLE=""
	if [[ ${STEP+found} == found ]]; then
		_STITLE="$STEP"
		unset STEP
	fi

	local -r BUILDAH_NAME_BASE=$1

	# no arg callback
	local -r BUILDAH_HASH_CALLBACK=$2

	# arg1=working container name [must create container this name]
	local -r BUILDAH_BUILD_CALLBACK=$3

	if [[ ${_CURRENT_STAGE_STORE[$BUILDAH_NAME_BASE]+found} == 'found' ]]; then
		local -ir CURRENT_STAGE="${_CURRENT_STAGE_STORE[$BUILDAH_NAME_BASE]}"
		local -ir NEXT_STAGE="${CURRENT_STAGE} + 1"
	else
		local -ir CURRENT_STAGE=0
		local -ir NEXT_STAGE=1
	fi
	_CURRENT_STAGE_STORE[$BUILDAH_NAME_BASE]="$NEXT_STAGE"

	info "[$BUILDAH_NAME_BASE] STEP $NEXT_STAGE: \e[0;38;5;11m$_STITLE"
	indent

	local -r BUILDAH_FROM="$BUILDAH_CACHE_BASE:${BUILDAH_NAME_BASE}-stage-$CURRENT_STAGE"
	if [[ $CURRENT_STAGE -gt 0 ]]; then
		if ! image_exists "$BUILDAH_FROM"; then
			die "required previous stage [$BUILDAH_FROM] did not exists"
		fi
		local -r PREVIOUS_ID=$(buildah inspect --type image --format '{{.FromImageID}}' "$BUILDAH_FROM")
		if [[ ! $PREVIOUS_ID ]]; then
			die "failed get id from image ($BUILDAH_FROM) cache state is invalid."
		fi
	else
		local -r PREVIOUS_ID="none"
	fi
	local -r BUILDAH_TO="$BUILDAH_CACHE_BASE:${BUILDAH_NAME_BASE}-stage-$NEXT_STAGE"

	if [[ ${BUILDAH_FORCE-no} != "yes" ]]; then
		cache_try_pull "$BUILDAH_TO"
	fi

	local WANTED_HASH HASH_TMP
	HASH_TMP=$(mktemp)
	"$BUILDAH_HASH_CALLBACK" >"$HASH_TMP"
	WANTED_HASH=$(awk '{print $1}' "$HASH_TMP")
	unlink "$HASH_TMP"

	if [[ ${BUILDAH_FORCE-no} == "yes" ]]; then
		info_warn "cache skip <BUILDAH_FORCE=yes> target=$WANTED_HASH"
	elif image_exists "$BUILDAH_TO"; then
		local -r EXISTS_PREVIOUS_ID="$(builah_get_annotation "$BUILDAH_TO" "$ANNOID_CACHE_PREV_STAGE")"
		local -r EXISTS_HASH="$(builah_get_annotation "$BUILDAH_TO" "$ANNOID_CACHE_HASH")"

		if [[ ! $EXISTS_PREVIOUS_ID ]] || [[ ! $EXISTS_HASH ]]; then
			die "failed get annotation from image ($BUILDAH_TO) cache state is invalid."
		fi

		info_success "cache exists <hash=$EXISTS_HASH, base=$EXISTS_PREVIOUS_ID>"
		if [[ "$EXISTS_HASH++$EXISTS_PREVIOUS_ID" == "$WANTED_HASH++$PREVIOUS_ID" ]]; then
			BUILDAH_LAST_IMAGE=$(buildah inspect --type image --format '{{.FromImageID}}' "$BUILDAH_TO")
			cache_push "$BUILDAH_TO"
			_buildah_cache_done
			return
		fi
		info_note "cache outdat <want=$WANTED_HASH, base=$PREVIOUS_ID>"
	else
		info_warn "step result not cached: target=$WANTED_HASH"
	fi

	LAST_CACHE_COMES_FROM=build
	local -r CONTAINER_ID="${BUILDAH_NAME_BASE}_from${CURRENT_STAGE}_to${NEXT_STAGE}"
	"$BUILDAH_BUILD_CALLBACK" "$CONTAINER_ID"
	info_note "build callback finish"

	if ! container_exists "$CONTAINER_ID"; then
		die "BUILDAH_BUILD_CALLBACK<$BUILDAH_BUILD_CALLBACK> did not create $CONTAINER_ID."
	fi

	buildah config --add-history \
		"--annotation=$ANNOID_CACHE_HASH=$WANTED_HASH" \
		"--annotation=$ANNOID_CACHE_PREV_STAGE=$PREVIOUS_ID" \
		"--created-by=# layer <$CURRENT_STAGE> to <$NEXT_STAGE> base $BUILDAH_NAME_BASE" \
		"$CONTAINER_ID" >/dev/null
	BUILDAH_LAST_IMAGE=$(xbuildah commit --omit-timestamp --rm "$CONTAINER_ID" "$BUILDAH_TO")
	info_note "$BUILDAH_LAST_IMAGE"

	cache_push "$BUILDAH_TO"

	_buildah_cache_done
}

_buildah_cache_done() {
	dedent
	if [[ "$_STITLE" ]]; then
		info_note "[$BUILDAH_NAME_BASE] STEP $NEXT_STAGE (\e[0;38;5;13m$_STITLE\e[0;2m) DONE | BUILDAH_LAST_IMAGE=$BUILDAH_LAST_IMAGE\n"
	else
		info_note "[$BUILDAH_NAME_BASE] STEP $NEXT_STAGE DONE | BUILDAH_LAST_IMAGE=$BUILDAH_LAST_IMAGE\n"
	fi
}

function buildah_cache_start() {
	local BASE_IMG=$1
	if [[ $BASE_IMG != scratch ]]; then
		if ! image_exists "$BASE_IMG"; then
			podman pull --quiet "$BASE_IMG"
		fi
		BUILDAH_LAST_IMAGE=$(image_get_id "$BASE_IMG")
	else
		BUILDAH_LAST_IMAGE="$BASE_IMG"
	fi
}

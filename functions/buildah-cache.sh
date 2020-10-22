declare -A _CURRENT_STAGE_STORE=()
declare -r BUILDAH_CACHE_BASE="${DOCKER_CACHE_CENTER:-cache.example.com}"

CACHE_REGISTRY_ARGS=()
if [[ ${DOCKER_CACHE_CENTER_AUTH:-} ]]; then
	CACHE_REGISTRY_ARGS+=("--creds=$DOCKER_CACHE_CENTER_AUTH")
fi

function cache_try_pull() {
	if [[ ! ${DOCKER_CACHE_CENTER:-} ]]; then
		return
	fi

	local OUTPUT
	local URL="$1"
	for ((I = 0; I < 3; I++)); do
		info_note "try pull cache image $URL"
		if OUTPUT=$(run_without_proxy podman pull "${CACHE_REGISTRY_ARGS[@]}" "$URL" 2>&1); then
			info_note "  - success."
			return
		else
			if echo "$OUTPUT" | grep -q -- 'manifest unknown'; then
				info_note " - failed, not exists."
				return
			else
				info_note " - failed."
			fi
		fi
	done

	echo "$OUTPUT" >&2
	die "failed pull cache image!"
}
function cache_push() {
	if [[ ! ${DOCKER_CACHE_CENTER:-} ]]; then
		return
	fi

	local URL="$1"
	info_note "push cache image $URL"
	run_without_proxy podman push "${CACHE_REGISTRY_ARGS[@]}" "$URL"
}

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

	local -r BUILDAH_FROM="$BUILDAH_CACHE_BASE/cache/$BUILDAH_NAME_BASE:stage-$CURRENT_STAGE"
	if [[ $CURRENT_STAGE -gt 0 ]]; then
		if ! image_exists "$BUILDAH_FROM"; then
			die "required previous stage [$BUILDAH_FROM] did not exists"
		fi
		local -r PREVIOUS_ID=$(buildah inspect --type image --format '{{.FromImageID}}' "$BUILDAH_FROM")
	else
		local -r PREVIOUS_ID="none"
	fi
	local -r BUILDAH_TO="$BUILDAH_CACHE_BASE/cache/$BUILDAH_NAME_BASE:stage-$NEXT_STAGE"

	cache_try_pull "$BUILDAH_TO"

	local WANTED_HASH
	WANTED_HASH=$("$BUILDAH_HASH_CALLBACK" | awk '{print $1}')

	if [[ ${BUILDAH_FORCE-no} == "yes" ]]; then
		info_note "cache skip <BUILDAH_FORCE=yes> target=$WANTED_HASH"
	elif image_exists "$BUILDAH_TO"; then
		local -r EXISTS_PREVIOUS_ID="$(builah_get_annotation "$BUILDAH_TO" "$ANNOID_CACHE_PREV_STAGE")"
		local -r EXISTS_HASH="$(builah_get_annotation "$BUILDAH_TO" "$ANNOID_CACHE_HASH")"
		info_note "cache exists <hash=$EXISTS_HASH, base=$EXISTS_PREVIOUS_ID>"
		if [[ "$EXISTS_HASH++$EXISTS_PREVIOUS_ID" == "$WANTED_HASH++$PREVIOUS_ID" ]]; then
			BUILDAH_LAST_IMAGE=$(buildah inspect --type image --format '{{.FromImageID}}' "$BUILDAH_TO")
			cache_push "$BUILDAH_TO"
			_buildah_cache_done
			return
		fi
		info_note "cache outdat <want=$WANTED_HASH, base=$PREVIOUS_ID>"
	else
		info_note "step result not cached: target=$WANTED_HASH"
	fi

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
	local NAME=$1 BASE_IMG=$2
	if [[ $BASE_IMG != scratch ]]; then
		if ! image_exists "$BASE_IMG"; then
			podman pull --quiet "$BASE_IMG"
		fi
		BUILDAH_LAST_IMAGE=$(image_get_id "$BASE_IMG")
	else
		BUILDAH_LAST_IMAGE="$BASE_IMG"
	fi
}

# buildah_cache2
function buildah_cache2() {
	local -r NAME=$1 HASH_CALLBACK=$2 BUILD_CALLBACK=$3

	_hash_cb() {
		{
			echo "$BUILDAH_LAST_IMAGE"
			"$HASH_CALLBACK"
		} | md5sum
	}
	_build_cb() {
		local CONTAINER
		CONTAINER=$(new_container "$1" "$BUILDAH_LAST_IMAGE")
		"$BUILD_CALLBACK" "$CONTAINER"
	}

	buildah_cache "$NAME" _hash_cb _build_cb

	unset -f _hash_cb _build_cb
}

function buildah_cache_fork() {
	local -r NAME=$1
	shift
	local -r NEW_BASE=$1
	shift
	local -r HASH_CALLBACK=$1
	shift
	local -r BUILD_CALLBACK=$1

	local -r FROM_IMAGE="$BUILDAH_LAST_IMAGE"
	buildah_cache_start "$NAME" "$NEW_BASE"

	_hash_bcf_cb() {
		{
			echo "base: $BUILDAH_LAST_IMAGE"
			echo "from: $FROM_IMAGE"
			"$HASH_CALLBACK"
		} | md5sum
	}
	_build_bcf_cb() {
		local SOURCE TARGET MNT
		SOURCE=$(new_container "${NAME}-fork-from" "$FROM_IMAGE")

		TARGET=$(new_container "$1" "$BUILDAH_LAST_IMAGE")
		MNT=$(buildah mount "$TARGET")

		"$BUILD_CALLBACK" "$SOURCE" "$TARGET" "$MNT"
	}

	buildah_cache "$NAME" _hash_bcf_cb _build_bcf_cb

	unset -f _hash_bcf_cb _build_bcf_cb
}

function buildah_cache_fork_script() {
	local -r NAME=$1
	shift
	local -r NEW_BASE=$1
	shift
	local -r BUILD_SCRIPT=$1
	shift
	local -ar BARGS=("$@")

	_hash_cfs_cb() {
		{
			echo "script: $BUILD_SCRIPT"
			echo "args: ${BARGS[*]}"
		} | md5sum
	}
	_build_cfs_cb() {
		{
			echo "set -Eeuo pipefail"
			echo "declare -rx DIST_FOLDER=/mnt/dist"
			cat "$BUILD_SCRIPT"
		} | buildah run "--volume=$MNT:/mnt/dist" "$SOURCE" bash -s - "${BARGS[@]}"
	}

	buildah_cache_fork "$NAME" "$NEW_BASE" _hash_cfs_cb _build_cfs_cb

	unset -f _hash_cfs_cb _build_cfs_cb
}

## buildah_cache_run ID ScriptFilePath [Bind:Mount ...] -- [bash args...]
function buildah_cache_run() {
	local NAME=$1
	shift
	local -r BUILD_SCRIPT=$1
	shift

	local -a BASH_ARGS=()
	local -a RUN_ARGS=()
	local -a HASH_FOLDERS=()
	if [[ $# -gt 0 ]]; then
		local SPFOUND=no
		for I; do
			if [[ $SPFOUND == yes ]]; then
				BASH_ARGS+=("$I")
			elif [[ $I == '--' ]]; then
				SPFOUND=yes
			else
				RUN_ARGS+=("$I")
				if [[ $I == "--volume="* ]]; then
					local X="${I//:*/}"
					HASH_FOLDERS+=("${X#--volume=}")
				fi
			fi
		done
		if [[ $SPFOUND == no ]]; then
			die "argument list require a '--'"
		fi
	fi

	_hash_cb() {
		{
			echo "last: $BUILDAH_LAST_IMAGE"
			cat "script: $BUILD_SCRIPT"
			echo "run: ${RUN_ARGS[*]}"
			echo "bash: ${BASH_ARGS[*]}"
			git ls-tree -r -t HEAD "${HASH_FOLDERS[@]}" || true
		} | md5sum
	}
	_build_cb() {
		local CONTAINER
		CONTAINER=$(new_container "$1" "$BUILDAH_LAST_IMAGE")

		buildah run "--cap-add=CAP_SYS_ADMIN" "${RUN_ARGS[@]}" "$CONTAINER" \
			bash -s - "${BASH_ARGS[@]}" <"$BUILD_SCRIPT"
	}

	buildah_cache "$NAME" _hash_cb _build_cb

	unset -f _hash_cb _build_cb
}

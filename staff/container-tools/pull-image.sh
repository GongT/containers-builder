#!/usr/bin/env bash

source "../../package/include.sh"

if [[ $# -ne 1 ]]; then
	die "Usage: $0 <missing|always>"
fi
declare -r PULL_POLICY=$1

if [[ -z ${PODMAN_IMAGE_NAME} ]]; then
	die "missing environment: PODMAN_IMAGE_NAME"
fi

info "pull image '${PODMAN_IMAGE_NAME}' with policy '${PULL_POLICY}'"

OLD_ID=$(image_find_digist "${PODMAN_IMAGE_NAME}")
if [[ ${PULL_POLICY} != "always" && -n ${OLD_ID} ]]; then
	info_success "done, exists: ${OLD_ID}"
	exit 0
fi

LAST_PULL_DIR="${XDG_RUNTIME_DIR}/last-pull"
mkdir -p "${LAST_PULL_DIR}"
STORE_FILE="${LAST_PULL_DIR}/$(echo "${PODMAN_IMAGE_NAME}" | sed -E 's#[./-:]#_#g' | sed -E 's#__+#_#g')"
declare -i NOW LAST

NOW=$(date +%s)
if [[ -n ${OLD_ID} && -e ${STORE_FILE} ]]; then
	if [[ ${FORCE_PULL-} == 'yes' ]]; then
		info_warn "request force"
	else
		LAST=$(<"${STORE_FILE}")
		LASTSTR=$(TZ=CST date --date="@${LAST}" "+%F %T")
		if [[ ${NOW} -lt $((LAST + 3600)) ]]; then
			info_success "done: ${OLD_ID} @${LASTSTR}"
			exit 0
		else
			info_note "state expired: ${OLD_ID} @${LASTSTR}"
		fi
	fi
else
	info_note "first time pull."
fi

unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY

info_log "pulling from registry..."
load_sdnotify

declare -i TRIES=1 MAX_TRY=5
while true; do
	sdnotify "--status=[${TRIES}/${MAX_TRY}] pull ${PODMAN_IMAGE_NAME}" "EXTEND_TIMEOUT_USEC=$((30 * 1000000))"
	if podman image pull --retry 1 "${PODMAN_IMAGE_NAME}"; then
		break
	fi

	TRIES+=1
	if [[ ${TRIES} -gt ${MAX_TRY} ]]; then
		sdnotify --stopping "--status=failed pull image ${PODMAN_IMAGE_NAME}"
		info_note "failed after ${MAX_TRY} times."
		exit 1
	fi

	sleep 3s
done

sdnotify "--status=pull complete"

NEW_ID=$(image_find_digist "${PODMAN_IMAGE_NAME}")

if [[ ${OLD_ID} == "${NEW_ID}" ]]; then
	info_success "image is up to date: ${OLD_ID}"
else
	info_success "downloaded newer image: ${NEW_ID}"
fi
printf '%s' "${NOW}" >"${STORE_FILE}"

if [[ ${SKIP_REMOVE+found} != found ]]; then
	info_note "removing unused images:"
	podman images \
		| grep --fixed-strings '<none>' \
		| awk '{print $3}' \
		| while read -r IMAGE_ID; do
			sdnotify "--status=[${TRIES}/${MAX_TRY}] pull ${PODMAN_IMAGE_NAME}" "EXTEND_TIMEOUT_USEC=$((30 * 1000000))"
			podman image rm "${IMAGE_ID}" || true
		done
fi

sdnotify "EXTEND_TIMEOUT_USEC=$((10 * 1000000))"

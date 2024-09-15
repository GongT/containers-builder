#!/usr/bin/env bash

function image_get_id() {
	podman image inspect --format '{{.Id}}' "${IMAGE_TO_PULL}" 2>/dev/null | grep -ioE '^[0-9a-f]{12}' || true
}
function log() {
	echo "$*"
}

declare -r IMAGE_TO_PULL=$1 PULL_POLICY=$2
log "start pull image '${IMAGE_TO_PULL}' with policy '${PULL_POLICY}'"

OLD_ID=$(image_get_id)
if [[ ${PULL_POLICY} != "always" ]]; then
	if [[ -n ${OLD_ID} ]]; then
		log "done, exists: ${OLD_ID}"
		exit 0
	fi
fi

LAST_PULL_DIR="${XDG_RUNTIME_DIR}/last-pull"
mkdir -p "${LAST_PULL_DIR}"
STORE_FILE="${LAST_PULL_DIR}/$(echo "${IMAGE_TO_PULL}" | sed -E 's#[./-:]#_#g' | sed -E 's#__+#_#g')"
declare -i NOW LAST

NOW=$(date +%s)
if [[ -n ${OLD_ID} && -e ${STORE_FILE} ]]; then
	LAST=$(<"${STORE_FILE}")
	LASTSTR=$(TZ=CST date --date="@${LAST}" "+%F %T")

	if [[ ${FORCE_PULL-} == 'yes' ]]; then
		log "request force"
	else
		if [[ ${NOW} -lt $((LAST + 3600)) ]]; then
			log "done: ${OLD_ID} @${LASTSTR}"
			exit 0
		else
			log "state expired: ${OLD_ID} @${LASTSTR}"
		fi
	fi
else
	log "first time pull."
fi

unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY

log "pulling from registry..."

declare -i TRIES=1 MAX_TRY=5
while true; do
	systemd-notify "--status=[${TRIES}/${MAX_TRY}] pull ${IMAGE_TO_PULL}" "EXTEND_TIMEOUT_USEC=$((30 * 1000000))"
	if podman image pull --retry 1 "${IMAGE_TO_PULL}"; then
		break
	fi

	TRIES+=1
	if [[ ${TRIES} -gt ${MAX_TRY} ]]; then
		systemd-notify --stopping "--status=failed pull image ${IMAGE_TO_PULL}"
		log "failed after ${MAX_TRY} times."
		exit 1
	fi

	sleep 3s
done

systemd-notify "--status=pull complete"

NEW_ID=$(image_get_id)

if [[ ${OLD_ID} == "${NEW_ID}" ]]; then
	log "image is up to date: ${OLD_ID}"
else
	log "downloaded newer image: ${NEW_ID}"
fi
printf '%s' "${NOW}" >"${STORE_FILE}"

if [[ ${SKIP_REMOVE+found} != found ]]; then
	log "removing unused images:"
	podman images \
		| grep --fixed-strings '<none>' \
		| awk '{print $3}' \
		| while read -r IMAGE_ID; do
			systemd-notify "--status=[${TRIES}/${MAX_TRY}] pull ${IMAGE_TO_PULL}" "EXTEND_TIMEOUT_USEC=$((30 * 1000000))"
			podman rmi "${IMAGE_ID}" || true
		done
fi

systemd-notify "EXTEND_TIMEOUT_USEC=$((10 * 1000000))"

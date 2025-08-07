CONTAINER_DIGIST_LONG=$(grep -F .containerenv /proc/self/mountinfo | grep -oE '[0-9a-f]{64}' || true)
CONTAINER_DIGIST_SHORT="$(echo "${CONTAINER_DIGIST_LONG}" | grep -oE '^[0-9a-f]{12}')"

exportenv 'CONTAINER_DIGIST_LONG' "${CONTAINER_DIGIST_LONG}"
exportenv 'CONTAINER_DIGIST_SHORT' "${CONTAINER_DIGIST_SHORT}"
exportenv 'CONTAINER_ID' "${CONTAINER_ID-}"

#####
declare -p CONTAINER_ID CONTAINER_DIGIST_SHORT container_uuid
#####

# this variable is set by `podman --systemd=always`, 32 digits
echo "${container_uuid-"debugger container $RANDOM"}" >/etc/machine-id
cat /etc/machine-id >/run/machine-id

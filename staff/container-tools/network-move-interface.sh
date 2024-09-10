#!/usr/bin/env bash

set -Eeuo pipefail

function die() {
	if [[ ${NET_NAMESPACE+found} != found ]]; then
		ip netns delete "${NET_NAMESPACE}" &>/dev/null || true
	fi
	echo "$*" >&2
	exit 1
}

set -a
for I; do
	eval "${I}" &>/dev/null || true
done
set +a

if [[ ${INTERFACE_NAME+found} != found ]] || [[ ${NET_NAMESPACE+found} != found ]] || [[ ${INTERFACE_NAME_INSIDE+found} != found ]]; then
	echo "INTERFACE_NAME=${INTERFACE_NAME:-not found}"
	echo "INTERFACE_NAME_INSIDE=${INTERFACE_NAME_INSIDE:-not found}"
	echo "NET_NAMESPACE=${NET_NAMESPACE:-not found}"
	die "Invalid call"
fi

function move_in() {
	echo "move interface ${NET_NAMESPACE} into ns:${NET_NAMESPACE} with name ${INTERFACE_NAME_INSIDE}"

	if ! ip netns list 2>&1 | grep -q -- "${NET_NAMESPACE}"; then
		echo "create new namespace ${NET_NAMESPACE}"
		ip netns add "${NET_NAMESPACE}" || die "Failed create network namespace"
	else
		echo "use exists namespace ${NET_NAMESPACE}"
	fi

	IF_OUT=$(ip link show "${INTERFACE_NAME}" 2>/dev/null || true)
	if [[ -n ${IF_OUT} ]]; then
		echo "${IF_OUT}"
		INTERFACE_NAME=$(echo "${IF_OUT}" | head -1 | awk '{print $2}' | sed 's/://g')
	fi

	if [[ -e "/sys/class/net/${INTERFACE_NAME}" ]]; then
		echo "found interface ${INTERFACE_NAME} on host"

		if ! echo "${IF_OUT}" | grep -q -- "state DOWN"; then
			echo "${IF_OUT}"
			die "Interface ${INTERFACE_NAME} is not state DOWN"
		fi

		IW_PHY_NAME_FILE="/sys/class/net/${INTERFACE_NAME}/device/ieee80211/phy0/name"
		if [[ -e ${IW_PHY_NAME_FILE} ]]; then
			IF_PHY=$(<"${IW_PHY_NAME_FILE}") || die "Failed detect wireless phy id"
			echo "found wireless phy: ${IF_PHY}"
			iw phy "${IF_PHY}" set netns name "${NET_NAMESPACE}" || die "Failed move wireless interface into namespace"
		else
			ip link set "${INTERFACE_NAME}" netns "${NET_NAMESPACE}" || die "Failed move network interface into namespace"
		fi
	else
		echo "no such interface on host"
		if ip netns exec "${NET_NAMESPACE}" ip link show "${INTERFACE_NAME}" &>/dev/null; then
			echo "it's already inside namespace"
			ip netns exec "${NET_NAMESPACE}" ip link set "${INTERFACE_NAME}" down || die "Failed set interface down"
		elif ip netns exec "${NET_NAMESPACE}" ip link show "${INTERFACE_NAME_INSIDE}" &>/dev/null; then
			echo "it's already inside namespace as ${INTERFACE_NAME_INSIDE}"
			ip netns exec "${NET_NAMESPACE}" ip link set "${INTERFACE_NAME_INSIDE}" down || die "Failed set interface down"
			exit 0
		else
			die "no interface (down state) named ${INTERFACE_NAME}"
		fi
	fi

	if [[ -n "${INTERFACE_NAME_INSIDE}" ]] && [[ ${INTERFACE_NAME_INSIDE} != "${INTERFACE_NAME}" ]]; then
		echo "rename interface in namespace to ${INTERFACE_NAME_INSIDE}"
		ip netns exec "${NET_NAMESPACE}" ip link set "${INTERFACE_NAME}" name "${INTERFACE_NAME_INSIDE}" || die "Failed rename interface"
	else
		echo "interface no need rename"
	fi
}

function move_out() {
	echo "move interface ${INTERFACE_NAME_INSIDE} from ns:${NET_NAMESPACE} with name ${INTERFACE_NAME}"

	if ! ip netns list 2>&1 | grep -q -- "${NET_NAMESPACE}"; then
		echo "namespace not exists"
		exit 0
	fi
	if [[ -n "${INTERFACE_NAME_INSIDE}" ]] && [[ ${INTERFACE_NAME_INSIDE} != "${INTERFACE_NAME}" ]]; then
		if ip netns exec "${NET_NAMESPACE}" ip link show "${INTERFACE_NAME_INSIDE}" &>/dev/null; then
			echo "found interface ${INTERFACE_NAME_INSIDE} in namespace"
			ip netns exec "${NET_NAMESPACE}" ip link set "${INTERFACE_NAME_INSIDE}" down || die "Failed set interface down"
			ip netns exec "${NET_NAMESPACE}" ip link set "${INTERFACE_NAME_INSIDE}" name "${INTERFACE_NAME}" || die "Failed rename interface"
		else
			echo "no interface ${INTERFACE_NAME_INSIDE} in namespace"
		fi
	fi

	if ! ip netns exec "${NET_NAMESPACE}" ip link show "${INTERFACE_NAME}" &>/dev/null; then
		echo "no interface ${INTERFACE_NAME} in namespace"
		exit 0
	fi
	echo "found interface ${INTERFACE_NAME} in namespace"
	ip netns exec "${NET_NAMESPACE}" ip link set "${INTERFACE_NAME}" down || die "Failed set interface down"

	IW_PHY_NAME_FILE="/sys/class/net/${INTERFACE_NAME}/device/ieee80211/phy0/name"
	if ip netns exec "${NET_NAMESPACE}" bash -c "[[ -e '${IW_PHY_NAME_FILE}' ]]"; then
		IF_PHY=$(ip netns exec "${NET_NAMESPACE}" cat "${IW_PHY_NAME_FILE}") || die "Failed detect wireless phy id"
		echo "found wireless phy: ${IF_PHY}"
		ip netns exec "${NET_NAMESPACE}" iw phy "${IF_PHY}" set netns 1 || die "Failed move wireless interface out"
	else
		ip netns exec "${NET_NAMESPACE}" ip link set "${INTERFACE_NAME_INSIDE}" netns 1 || die "Failed move network interface out"
	fi
	echo "interface moved out"
}

if [[ $* == *'--out'* ]]; then
	move_out
else
	move_in
fi

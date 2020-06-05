#!/usr/bin/env bash

set -Eeuo pipefail

MACHINE=$2

function info() {
	echo "{update-hosts} $*" >&2
}

TAG=" ### auto:$MACHINE"
OLD_VALUE=$(grep --fixed-strings "$TAG" /etc/hosts | grep -Eo '^\S+' || echo '')

function signal_dnsmasq() {
	info "send SIGHUP to dnsmasq..."
	PID_DNS=$(systemctl show --property MainPID --value dnsmasq)
	if [[ "$PID_DNS" -gt 0 ]]; then
		kill -s SIGHUP $PID_DNS || true
		info 'ok.'
	else
		info "not running..."
	fi
}

function add() {
	IP=$(podman inspect "$MACHINE" --format '{{.NetworkSettings.IPAddress}}' || echo '')
	info "bind ip address $IP with $MACHINE"
	if [[ "$IP" == "$OLD_VALUE" ]]; then
		info 'ip is same.'
		return
	elif [[ ! "$IP" ]]; then
		IP='# ip not found'
	fi

	HOSTS="$(grep --fixed-strings -v "$TAG" /etc/hosts | sed -e :a -e '/^\n*$/{$d;N;};/\n$/ba')"
	{
		echo "$HOSTS"
		echo "$IP $MACHINE $TAG"
	} > /etc/hosts
	info 'ok.'
	signal_dnsmasq
}

function del() {
	info "remove ip address of $MACHINE"
	if [[ "$OLD_VALUE" ]]; then
		HOSTS="$(grep --fixed-strings -v "$TAG" /etc/hosts)"
		echo "$HOSTS" > /etc/hosts
	else
		info "not exists"
		return
	fi
	info 'ok.'
	signal_dnsmasq
}

if [[ $1 == "add" ]]; then
	add
elif [[ $1 == "del" ]]; then
	del
else
	echo "unknown value: $1"
fi

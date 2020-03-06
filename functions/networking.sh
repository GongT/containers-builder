
IS_NAT=$(ip addr | grep 10\\.0\\.1\\.1 || true)
if [[ -n "$IS_NAT" ]] ; then
	IS_NAT=yes
	NETWORK_TYPE="--network=container:virtual-gateway"
	INFRA_DEP="virtual-gateway.service"
else
	IS_NAT=
	NETWORK_TYPE="--network=host"
	INFRA_DEP="wait-mount.service"
fi

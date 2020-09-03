set -Eeuo pipefail

rm -rf /install-root/var/lib/dnf
rm -rf /install-root/var/lib/rpm
mkdir -p /install-root/var/lib
ln -s "/cache/$WORKER/dnf" /install-root/var/lib/dnf
ln -s "/cache/$WORKER/rpm" /install-root/var/lib/rpm

if [[ ! -e "/install-root/var/lib/dnf.signal" ]]; then
	rm -rf "/cache/$WORKER/dnf" "/cache/$WORKER/rpm"
	touch /install-root/var/lib/dnf.signal
fi
mkdir -p "/cache/$WORKER/dnf" "/cache/$WORKER/rpm"

echo "    installing ${ARGS[*]}" >&2
cd /
/usr/bin/dnf install -y --releasever=/ --installroot=/install-root \
	--setopt=cachedir=../../../../../var/cache/dnf \
	"${ARGS[@]}"

DIRS_SHOULD_EMPTY=(/install-root/var/log /install-root/tmp)
rm -rf "${DIRS_SHOULD_EMPTY[@]}" /install-root/var/lib/dnf /install-root/var/lib/rpm
mkdir -p "${DIRS_SHOULD_EMPTY[@]}"
chmod 0777 "${DIRS_SHOULD_EMPTY[@]}"

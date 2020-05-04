set -Eeuo pipefail

rm -rf /install-root/var/lib/dnf
rm -rf /install-root/var/lib/rpm
mkdir -p /install-root/var/lib
ln -s "/cache/$WORKER/dnf" /install-root/var/lib/dnf
ln -s "/cache/$WORKER/rpm" /install-root/var/lib/rpm

if [[ ! -e "/install-root/var/lib/dnf.signal" ]]; then
	rm -rf "/cache/$WORKER/dnf" "/cache/$WORKER/rpm"

	mkdir -p "/install-root/var/lib"
	touch /install-root/var/lib/dnf.signal
fi
mkdir -p "/cache/$WORKER/dnf" "/cache/$WORKER/rpm"

echo "    installing ${ARGS[*]}" >&2
cd /
/usr/bin/dnf install -y --releasever=/ --installroot=/install-root \
	--setopt=cachedir=../../../../../var/cache/dnf \
	"${ARGS[@]}"

rm -rf /install-root/var/log
mkdir -p /install-root/var/log
chmod 0777 /install-root/var/log

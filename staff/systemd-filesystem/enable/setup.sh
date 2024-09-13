function enable_all() {
	PATHS=(
		/usr/local/lib/systemd/system
		/etc/systemd/system
	)

	ALL_FILES=()
	for PAT in "${PATHS[@]}"; do
		if [[ ! -d $I ]]; then
			continue
		fi

		find "$PAT" -maxdepth 1 '(' -type f -o type l ')' -print0 | while read -d '' -r FILE; do
			if [[ $(readlink "${FILE}" || true) == '/dev/null' ]]; then
				continue
			fi

			if ! grep -qF "[Install]" "${FILE}"; then
				continue
			fi

			NAME="$(basename "${FILE}")"
			ALL_FILES+=("$NAME")
		done
	done

	x systemctl enable "${ALL_FILES[@]}" || true
	add_after "${ALL_FILES[*]}"
}
function add_after() {
	mkdir -p /etc/systemd/system/success.service.d
	cat >>/etc/systemd/system/success.service.d/after.conf <<-EOF
		[Unit]
		After=$*
		Requires=$*
	EOF
}

if [[ -n ${UNITS} ]]; then
	# shellcheck disable=SC2086
	x systemctl enable ${UNITS}
	# shellcheck disable=SC2086
	add_after ${UNITS}
else
	enable_all
fi

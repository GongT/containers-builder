function enable_all() {
	PATHS=(
		/usr/lib/systemd/system
		/usr/local/lib/systemd/system
		/etc/systemd/system
	)

	ALL_FILES=()
	for PAT in "${PATHS[@]}"; do
		if [[ ! -d $I ]]; then
			continue
		fi

		find "$PAT" -maxdepth 1 -type f -print0 | while read -d '' -r FILE; do
			if ! grep -qF "[Install]" "${FILE}"; then
				continue
			fi

			ALL_FILES+=("$(basename "${FILE}")")
		done
	done

	x systemctl enable "${ALL_FILES[@]}" || true
}

if [[ -n ${UNITS} ]]; then
	# shellcheck disable=SC2086
	x systemctl enable ${UNITS}
else
	enable_all
fi

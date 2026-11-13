#!/usr/bin/bash

function _handle() {
	local UNIT="$1" CALLBACK="$2"
	if ! systemd_unit_exists "$UNIT"; then
		log "单元文件不存在: $UNIT"
		exit 1
	fi
	if systemd_unit_can_enable "${UNIT}"; then
		ENABLES+=("$UNIT")
	fi
	"${CALLBACK}" "$UNIT"
}

function generate() {
	local UNIT REQ_ARR WANT_ARR BG_ARR ENABLES=()
	#shellcheck source=/dev/null
	source /entrypoint/systemd.d/enable.sh

	log "生成依赖关系: ${#REQ_ARR[@]} 必需 | ${#WANT_ARR[@]} 希望 | ${#BG_ARR[@]} 可选"
	for UNIT in "${REQ_ARR[@]}"; do
		_handle "$UNIT" systemd_unit_critical
	done
	for UNIT in "${WANT_ARR[@]}"; do
		_handle "$UNIT" systemd_unit_wanted
	done
	for UNIT in "${BG_ARR[@]}"; do
		_handle "$UNIT" systemd_unit_optional
	done

	log "启用的单元文件: ${#ENABLES[@]}: ${ENABLES[*]}"
	systemctl enable "${ENABLES[@]}"

	local FILE ALL_UNIT_FILES=()
	walk_dir ALL_UNIT_FILES /usr/local/lib/systemd/system _filter_contains_default_target
	for FILE in "${ALL_UNIT_FILES[@]}"; do
		log "处理文件: $FILE"
		sed -i "s#default.target#${DEFAULT_UNIT_NAME}#g" "$FILE"
	done
	walk_dir ALL_UNIT_FILES /usr/lib/systemd/system _filter_contains_default_target
	for FILE in "${ALL_UNIT_FILES[@]}"; do
		log "处理文件: $FILE"
		sed -i "s#default.target#${DEFAULT_UNIT_NAME}#g" "$FILE"
	done
}

function _filter_contains_default_target() {
	grep -qF "default.target" "$1"
}

generate
unset -f generate _filter_contains_default_target _handle

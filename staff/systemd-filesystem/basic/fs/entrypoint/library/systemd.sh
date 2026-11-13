DEFAULT_UNIT_NAME=$(systemctl get-default)

# _OPEN_UNIT_FILE=""
# _OPEN_UNIT_DATA=""
# function systemd_unit_open() {
# 	if [[ -n $_OPEN_UNIT_FILE ]]; then
# 		die "已经打开单元文件: $_OPEN_UNIT_FILE"
# 	fi
# 	local UNIT_NAME="$1" OVERRIDE_NAME="${2:-override}"
# 	_OPEN_UNIT_FILE="/etc/systemd/system/$UNIT_NAME.d/$OVERRIDE_NAME.conf"
# 	_OPEN_UNIT_DATA="$(<"$_OPEN_UNIT_FILE")"
# }
# function systemd_unit_close() {
# 	if [[ -z $_OPEN_UNIT_FILE ]]; then
# 		die "没有打开的单元文件"
# 	fi
#
# 	echo "$_OPEN_UNIT_DATA" >"$_OPEN_UNIT_FILE"
# 	_OPEN_UNIT_FILE=""
# 	_OPEN_UNIT_DATA=""
# }

# 修改unit文件:
#   1. 被default.target强依赖（Requires+After）
#   2. 失败时导致容器退出
function systemd_unit_critical() {
	local UNIT_NAME="$1"
	log "添加关键依赖: $UNIT_NAME"
	systemd_edit "default.target" "unit" 80-startup <<-EOF
		Requires=$UNIT_NAME
		After=$UNIT_NAME
	EOF
	systemd_edit "$UNIT_NAME" "unit" 80-failure-action <<-EOF
		FailureAction=exit
		FailureActionExitStatus=233
	EOF
}

# 修改unit文件:
#   1. 被default.target强依赖（Requires）
#   2. 失败时导致容器退出
function systemd_unit_wanted() {
	local UNIT_NAME="$1"
	log "添加弱依赖: $UNIT_NAME"
	systemd_edit "default.target" "unit" 80-startup <<-EOF
		Requires=$UNIT_NAME
	EOF
	systemd_edit "$UNIT_NAME" "unit" 80-failure-action <<-EOF
		FailureAction=exit
		FailureActionExitStatus=233
	EOF
}

# 修改unit文件:
#   1. 被default.target弱依赖（Wants）
#   2. 失败时不影响容器运行
function systemd_unit_optional() {
	local UNIT_NAME="$1"
	log "添加可选依赖: $UNIT_NAME"
	systemd_edit "default.target" "unit" 80-startup <<-EOF
		Wants=$UNIT_NAME
	EOF
}

# 编辑unit文件的指定section和key（通过override文件实现）
#
# example:
#    systemd_edit nginx.service install "WantedBy=default.target" 60-autostart
function systemd_edit() {
	local UNIT_NAME="$1" SECTION="$2" OVERRIDE_NAME="${3:-50-untitled-override}" CONTENT

	if ! [[ ${OVERRIDE_NAME} =~ ^[0-9]{2}-.* ]]; then
		die "重写文件名必须以两位数字开头，例如 50-untitled-override"
	fi

	CONTENT="$(cat)"

	if [[ ${UNIT_NAME} == default.target ]]; then
		UNIT_NAME="${DEFAULT_UNIT_NAME}"
	fi

	local TARGET_FILE="/etc/systemd/system/${UNIT_NAME}.d/${OVERRIDE_NAME}.$SECTION.conf"
	log "写入 $TARGET_FILE ..."
	if [[ ! -f $TARGET_FILE ]]; then
		mkdir -p "$(dirname "$TARGET_FILE")"
		touch "$TARGET_FILE"
		echo "[${SECTION^}]" >>"$TARGET_FILE"
	fi

	# $(...) 会删除末尾的换行，用 echo 加回来，这样输入有没有换行都不影响结果
	printf "%s\n" "${CONTENT}" >>"$TARGET_FILE"
}

function systemd_unit_can_enable() {
	systemctl cat "$1" 2>/dev/null | grep -qF "[Install]"
}
function systemd_unit_exists() {
	systemctl cat "$1" &>/dev/null
}

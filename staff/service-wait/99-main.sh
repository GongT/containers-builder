declare -i WAIT_ERROR=66
function core_switch() {
	case "${WAIT_TYPE}" in
	socket)
		wait_by_socket
		;;
	port)
		wait_by_port "${WAIT_ARGS%:*}" "${WAIT_ARGS#*:}"
		;;
	sleep)
		wait_by_sleep "$WAIT_ARGS"
		;;
	output)
		wait_by_output "$WAIT_ARGS"
		;;
	touch)
		wait_by_create_file "$WAIT_ARGS"
		;;
	healthy) exit 251 ;; # do nothing
	pass) exit 251 ;; # do nothing
	*)
		sdnotify "--status=脚本异常"
		echo "未定义的等待类型: ${WAIT_TYPE}" >&2
		return 233
		;;
	esac
}

function service_wait_success() {
	WAIT_ERROR=0
}

function service_wait_thread() {
	function _wait_exit() {
		local RET=$?
		trap - EXIT TERM INT ERR
		if [[ ${WAIT_ERROR} -eq 0 && ${RET} -eq 0 ]]; then
			return
		elif [[ ${RET} -eq 251 ]]; then
			exit 0 # no need wait
		else
			info_log "等待容器 '$(get_container_id)' 稳定运行失败。"

			sdnotify --stopping "未能等到容器稳定运行"

			local SPID
			SPID=$(get_service_property "MainPID")
			if [[ ${SPID} -gt 0 ]]; then
				info_log "向 podman 容器 ${SPID} 发送信号"
				while kill -0 "${SPID}" 2>/dev/null; do
					kill -s sigterm "${SPID}"
					sleep 5
				done
			fi

			info_log "容器主进程已退出，等待进程结束 (${RET})"
			exit "${RET}"
		fi
	}
	trap _wait_exit EXIT TERM INT ERR

	sleep 2
	local ARGS_HINT
	if [[ $WAIT_TYPE == output ]]; then
		ARGS_HINT=$(echo "${WAIT_ARGS}" | base64 --wrap=0)
	else
		ARGS_HINT="${WAIT_ARGS}"
	fi
	info_log "等待 $(get_container_id) 稳定运行, 等待类型=${WAIT_TYPE}, 参数: ${ARGS_HINT}"

	core_switch

	startup_done
}

function passing_sdnotify_socket() {
	# 根据传入的模式设置容器的 sdnotify 参数
	# 如果使用podman自己的healthcheck机制来判断容器健康状态，就需要把 sdnotify 设置为 healthy，这样容器内就无法使用它了，所以需要手动传入
	# 其他所有方式都直接通过参数传入
	local MODE=${1} INNER_NOTIFY_SOCKET="/run/host/systemd-notify.sock"
	if [[ ${MODE} == healthy ]]; then
		push_engine_param "--sdnotify=healthy"
		push_engine_param "--env=NOTIFY_SOCKET=${INNER_NOTIFY_SOCKET}"
		push_engine_param "--volume=${NOTIFY_SOCKET}:${INNER_NOTIFY_SOCKET}"
	else
		push_engine_param "--sdnotify=container"
		if [[ ! -e ${NOTIFY_SOCKET} ]]; then
			die "NOTIFY_SOCKET 文件不存在: ${NOTIFY_SOCKET}"
		fi
	fi
}

function execute_service_waiter_main() {
	detect_image_using_systemd

	push_engine_param "--log-level=warn" "--log-driver=none"
	push_engine_param "--name=$(get_container_id)" "--replace=true"
	push_engine_param "--env=INVOCATION_ID=${INVOCATION_ID}"
	push_engine_param "--env=CONTAINER_ID=$(get_container_id)"
	push_engine_param "--annotation=systemd.unit.invocation_id=${INVOCATION_ID}"
	push_engine_param "--annotation=systemd.unit.name=${UNIT_NAME}"

	ensure_mounts
	remove_old_socks

	if [[ ${START_WAIT_DEFINE} == auto ]]; then
		if is_image_has_healthcheck; then
			START_WAIT_DEFINE=healthy
		elif current_image_is_using_systemd; then
			START_WAIT_DEFINE=pass
		else
			START_WAIT_DEFINE=sleep:10
		fi
		info_log "自动探测到等待类型: ${START_WAIT_DEFINE}"
	fi
	if [[ ${START_WAIT_DEFINE} == touch || ${START_WAIT_DEFINE} == touch: ]]; then
		START_WAIT_DEFINE="touch:/startup.${RANDOM}.signal"
	fi

	local -r WAIT_TYPE=${START_WAIT_DEFINE%%:*}
	if [[ ${START_WAIT_DEFINE} == *:* ]]; then
		local -r WAIT_ARGS=${START_WAIT_DEFINE#*:}
	else
		local -r WAIT_ARGS=''
	fi

	passing_sdnotify_socket "${WAIT_TYPE}"
	push_engine_param "--env=WAIT_TYPE=${WAIT_TYPE}"
	push_engine_param "--env=WAIT_ARGS=${WAIT_ARGS}"

	apply_container_healthcheck

	wait_for_pid_and_notify

	make_arguments

	ensure_container_not_running

	service_wait_thread &

	podman_run_container
}

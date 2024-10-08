function detect_image_using_systemd() {
	# push_engine_param "--log-driver=passthrough"
	push_engine_param "--tty" "--attach=stdin,stdout,stderr"

	if [[ ${FORCE_SYSTEMD-} == "true" ]] || current_image_is_using_systemd; then
		info_log "image is systemd: forced=${FORCE_SYSTEMD-false}, label=${SYSTEMD_DEFINATION}"
		push_engine_param '--systemd=always'
		# push_engine_param '--privileged=true'
	else
		info_log "image not systemd: forced=${FORCE_SYSTEMD-false}, label=${SYSTEMD_DEFINATION-}"
		push_engine_param '--systemd=false'
	fi
}

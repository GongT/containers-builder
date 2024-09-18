buildah config "--label=${LABELID_USE_NGINX_ATTACH}=yes" "--volume=/run/nginx" "--volume=/run/sockets" "$1"

buildah config "--label=${LABELID_USE_NGINX_ATTACH}=yes" "--volume=/run/nginx/config" "--volume=/run/sockets" "$1"

#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

mkdir -p \
    "${NGINX_BASE_PATH}/sbin" \
    "${NGINX_BASE_PATH}/etc" \
    "${NGINX_BASE_PATH}/tmp" \
    "${NGINX_BASE_PATH}/log"

mv /etc/nginx/* "${NGINX_BASE_PATH}/etc/"
mv /usr/sbin/nginx "${NGINX_BASE_PATH}/sbin/"

chown -R root:root "${NGINX_BASE_PATH}"
chmod -R g+rwX "${NGINX_BASE_PATH}"
chmod 664 "${NGINX_BASE_PATH}"/etc/*.conf

# Forward request and error logs to docker log collector
ln -sf /dev/stdout "${NGINX_BASE_PATH}/log/access.log"
ln -sf /dev/stderr "${NGINX_BASE_PATH}/log/error.log"

# Nginx will try to access /var/log/nginx once, before even reading its
# configuration file. This results in a "permission denied" error, if
# Nginx does not have access to the default directory. Therefore we
# create it, but don't use it:
mkdir  -p /var/log/nginx
chown -R root:root /var/log/nginx
chmod -R g+rwX /var/log/nginx

# For backwards-compatibility, create the /application/Web directory:
mkdir  -p /application/Web
chown -R root:root /application/Web
chmod -R g+rwX /application/Web

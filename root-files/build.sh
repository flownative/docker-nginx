#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

useradd --home-dir "${NGINX_BASE_PATH}" --no-create-home --no-user-group --uid 1000 nginx
groupadd --gid 1000 nginx

mkdir -p \
    "${NGINX_BASE_PATH}/cache/application" \
    "${NGINX_BASE_PATH}/cache/resources" \
    "${NGINX_BASE_PATH}/etc" \
    "${NGINX_BASE_PATH}/modules" \
    "${NGINX_BASE_PATH}/sbin" \
    "${NGINX_BASE_PATH}/tmp"

mv /etc/nginx/* "${NGINX_BASE_PATH}/etc/"
mv /usr/sbin/nginx "${NGINX_BASE_PATH}/sbin/"
mv /usr/lib/nginx/modules/* "${NGINX_BASE_PATH}/modules/"

chown -R nginx:nginx "${NGINX_BASE_PATH}"
chmod -R g+rwX "${NGINX_BASE_PATH}"
chmod 664 "${NGINX_BASE_PATH}"/etc/*.conf

chmod -R g+rwX "${NGINX_BASE_PATH}"

chown -R nginx:nginx \
    "${NGINX_BASE_PATH}/cache" \
    "${NGINX_BASE_PATH}/tmp"

# Fix ownership of syslog-ng's etc directory because COPY in this Dockerfile
# will reset the owner too root even though it was 1000 set by the base image:
chown -R 1000:1000 "${SYSLOG_BASE_PATH}/etc"

# Nginx will try to access /var/log/nginx once, before even reading its
# configuration file. This results in a "permission denied" error, if
# Nginx does not have access to the default directory. Therefore we
# create it, but don't use it:
mkdir  -p /var/log/nginx
chown -R nginx:nginx /var/log/nginx
chmod -R g+rwX /var/log/nginx
chown -R nginx:nginx /usr/share/nginx

# For backwards-compatibility, create the /application/Web directory:
mkdir  -p /application/Web
chown -R root:root /application/Web
chmod -R g+rwX /application/Web

#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# The official Nginx image ships an "nginx" user at uid/gid 101. Beach expects
# this container to run as uid 1000, matching the PHP container it shares
# volumes with, so the user is recreated. The primary group stays "users" (gid
# 100), which is what the Debian-based predecessor of this image ended up with.
deluser nginx
delgroup nginx 2>/dev/null || true

adduser -u 1000 -G users -h "${NGINX_BASE_PATH}" -H -D nginx
addgroup -g 1000 nginx

mkdir -p \
    "${NGINX_BASE_PATH}/cache/application" \
    "${NGINX_BASE_PATH}/cache/resources" \
    "${NGINX_BASE_PATH}/etc" \
    "${NGINX_BASE_PATH}/etc/sites-enabled" \
    "${NGINX_BASE_PATH}/modules" \
    "${NGINX_BASE_PATH}/sbin" \
    "${NGINX_BASE_PATH}/tmp" \
    "${FLOWNATIVE_LOG_PATH}" \
    "${LOGROTATE_BASE_PATH}/var"

chown -R nginx:nginx "${FLOWNATIVE_LOG_PATH}" "${LOGROTATE_BASE_PATH}"
chmod -R g+rwX "${FLOWNATIVE_LOG_PATH}" "${LOGROTATE_BASE_PATH}"

# "modules" is a symlink to /usr/lib/nginx/modules whose contents are moved
# below, so it must not be moved along:
rm /etc/nginx/modules
rm -f /etc/nginx/conf.d/default.conf

mv /etc/nginx/* "${NGINX_BASE_PATH}/etc/"
mv /usr/sbin/nginx "${NGINX_BASE_PATH}/sbin/"
mv /usr/lib/nginx/modules/* "${NGINX_BASE_PATH}/modules/"

# The entrypoint of the official image is replaced by ours:
rm -rf /docker-entrypoint.sh /docker-entrypoint.d

chown -R nginx:nginx "${NGINX_BASE_PATH}"
chmod -R g+rwX "${NGINX_BASE_PATH}"
chmod 664 "${NGINX_BASE_PATH}"/etc/*.conf

chmod -R g+rwX "${NGINX_BASE_PATH}"

chown -R nginx:nginx \
    "${NGINX_BASE_PATH}/cache" \
    "${NGINX_BASE_PATH}/tmp"

# Nginx will try to access /var/log/nginx once, before even reading its
# configuration file. This results in a "permission denied" error, if
# Nginx does not have access to the default directory. Therefore we
# create it, but don't use it. The official image symlinks the log files
# to /dev/stdout and /dev/stderr, which we replace by a plain directory
# so that recursive chown does not follow those links:
rm -rf /var/log/nginx
mkdir -p /var/log/nginx
chown -R nginx:nginx /var/log/nginx
chmod -R g+rwX /var/log/nginx
chown -R nginx:nginx /usr/share/nginx

# For backwards-compatibility, create the /application/Web directory:
mkdir  -p /application/Web
chown -R root:root /application/Web
chmod -R g+rwX /application/Web

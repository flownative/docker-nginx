FROM harbor.flownative.io/docker/base:trixie-slim

LABEL org.opencontainers.image.authors="Robert Lemke <robert@flownative.com>"

# -----------------------------------------------------------------------------
# Nginx
# Latest versions: https://packages.debian.org/trixie/nginx

ENV NGINX_VERSION=1.26.3-3+deb13u7

ENV FLOWNATIVE_LIB_PATH=/opt/flownative/lib \
    NGINX_BASE_PATH=/opt/flownative/nginx \
    LOG_DEBUG=false

USER root

# Packages are needed for the following reasons:
#
# nginx             Nginx web server (includes core modules: SSL, HTTP/2, HTTP/3, realip, etc.)
# nginx-common      Nginx configuration files and common resources
# libnginx-mod-http-headers-more-filter  Add, set, and clear headers in responses
# ca-certificates   Up to date CA certificates for validation
# procps            Process functions used for checking running status and stopping Nginx

RUN install_packages \
    nginx=${NGINX_VERSION} \
    nginx-common=${NGINX_VERSION} \
    libnginx-mod-http-headers-more-filter \
    ca-certificates \
    procps \
    && rm /etc/nginx/sites-available/default \
    && rm /etc/nginx/sites-enabled/default

COPY root-files /
RUN /build.sh

EXPOSE 8080

# terminate with SIGQUIT which is handled gracefully by nginx
# contrary to SIGTERM which terminates nginx immediately.
STOPSIGNAL SIGQUIT

USER nginx
ENTRYPOINT ["/entrypoint.sh"]
CMD [ "run" ]

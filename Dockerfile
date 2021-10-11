FROM europe-docker.pkg.dev/flownative/docker/base:buster
MAINTAINER Robert Lemke <robert@flownative.com>

# -----------------------------------------------------------------------------
# Nginx
# Latest versions: https://packages.debian.org/buster/nginx

ENV NGINX_VERSION=1.14.2-2+deb10u4

ENV FLOWNATIVE_LIB_PATH=/opt/flownative/lib \
    NGINX_BASE_PATH=/opt/flownative/nginx \
    LOG_DEBUG=false

USER root
COPY --from=docker.pkg.github.com/flownative/bash-library/bash-library:1 /lib $FLOWNATIVE_LIB_PATH

# Packages are needed for the following reasons:
#
# nginx-common      Nginx
# nginx-extras      chunkin and headers module for Nginx
# ca-certificates   Up to date CA certificates for validation
# procps            Process functions used for checking running status and stopping Nginx

RUN install_packages \
    nginx-common=${NGINX_VERSION} \
    nginx-extras=${NGINX_VERSION} \
    ca-certificates \
    procps \
    && rm /etc/nginx/sites-available/default \
    && rm /etc/nginx/sites-enabled/default

COPY root-files /
RUN /build.sh

EXPOSE 8080

USER nginx
ENTRYPOINT ["/entrypoint.sh"]
CMD [ "run" ]

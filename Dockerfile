FROM docker.pkg.github.com/flownative/docker-base/base:buster
MAINTAINER Robert Lemke <robert@flownative.com>

LABEL org.label-schema.name="Beach Nginx"
LABEL org.label-schema.description="Docker image providing Nginx for Beach instances"
LABEL org.label-schema.vendor="Flownative GmbH"

# -----------------------------------------------------------------------------
# Nginx
# Latest versions: https://packages.debian.org/buster/nginx

ARG NGINX_VERSION
ENV NGINX_VERSION ${NGINX_VERSION}

ENV FLOWNATIVE_LIB_PATH=/opt/flownative/lib \
    NGINX_BASE_PATH=/opt/flownative/nginx \
    PATH="/opt/flownative/nginx/bin:$PATH" \
    LOG_DEBUG=false

COPY --from=docker.pkg.github.com/flownative/bash-library/bash-library:1 /lib $FLOWNATIVE_LIB_PATH

# Note: We need nginx-extras for the chunkin and more headers module and apache2-utils for the htpasswd command.
#       The gettext package provides "envsubst" for templating.
RUN install_packages \
    ca-certificates \
    nginx-common=${NGINX_VERSION} \
    nginx-extras=${NGINX_VERSION} \
    gettext \
    curl \
    procps \
    && rm /etc/nginx/sites-available/default \
    && rm /etc/nginx/sites-enabled/default

COPY root-files /
RUN /build.sh

EXPOSE 8080

USER 1000
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "/run.sh" ]

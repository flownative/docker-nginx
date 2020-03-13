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
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "run" ]

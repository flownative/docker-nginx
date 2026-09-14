# -----------------------------------------------------------------------------
# Build envsubst for the target architecture.
#
# This image needs the Go implementation of envsubst, not the GNU one from
# gettext: our templates escape Nginx' own variables as "$$var", which is
# a8m/envsubst syntax that GNU envsubst does not understand.
#
# The stage runs on the build platform and cross-compiles, so no emulation is
# involved.

FROM --platform=$BUILDPLATFORM golang:1-alpine AS envsubst-builder

ARG ENVSUBST_VERSION=v1.4.2
ARG TARGETOS
ARG TARGETARCH

WORKDIR /src
RUN go mod init envsubst-build \
    && go get github.com/a8m/envsubst/cmd/envsubst@${ENVSUBST_VERSION} \
    && CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
       go build -o /out/envsubst github.com/a8m/envsubst/cmd/envsubst

# -----------------------------------------------------------------------------
# The actual image

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

COPY --from=envsubst-builder /out/envsubst /usr/local/bin/envsubst

COPY root-files /
RUN /build.sh

EXPOSE 8080

# terminate with SIGQUIT which is handled gracefully by nginx
# contrary to SIGTERM which terminates nginx immediately.
STOPSIGNAL SIGQUIT

USER nginx
ENTRYPOINT ["/entrypoint.sh"]
CMD [ "run" ]

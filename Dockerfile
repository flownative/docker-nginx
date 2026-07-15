# -----------------------------------------------------------------------------
# Nginx
# Latest versions: https://hub.docker.com/_/nginx
#
# We track the "stable" branch of Nginx, which is what the Debian-based
# predecessor of this image used as well.

ARG NGINX_VERSION=1.30.3

# -----------------------------------------------------------------------------
# Build envsubst for the target architecture.
#
# This image needs the Go implementation of envsubst, not the GNU one which
# nginx:alpine happens to ship: our templates escape Nginx' own variables as
# "$$var", which is a8m/envsubst syntax that GNU envsubst does not understand.
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
# Build the headers-more module.
#
# There is no Alpine package for it, so it is compiled against the exact Nginx
# version of the base image. "--with-compat" is what allows the resulting
# module to be loaded by the official Nginx binary.

FROM nginx:${NGINX_VERSION}-alpine AS module-builder

ARG HEADERS_MORE_VERSION=0.39

RUN apk add --no-cache build-base curl linux-headers openssl-dev pcre-dev zlib-dev

WORKDIR /src

# NGINX_VERSION is provided as an ENV by the base image, which keeps the module
# and the binary it is loaded into in lockstep automatically.
RUN curl -fsSL "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" | tar -xz \
    && curl -fsSL "https://github.com/openresty/headers-more-nginx-module/archive/refs/tags/v${HEADERS_MORE_VERSION}.tar.gz" | tar -xz \
    && cd "nginx-${NGINX_VERSION}" \
    && ./configure \
        --with-compat \
        --add-dynamic-module="../headers-more-nginx-module-${HEADERS_MORE_VERSION}" \
    && make modules \
    && cp objs/ngx_http_headers_more_filter_module.so /out.so

# -----------------------------------------------------------------------------
# The actual image

FROM nginx:${NGINX_VERSION}-alpine

LABEL org.opencontainers.image.authors="Robert Lemke <robert@flownative.com>"

ENV FLOWNATIVE_LIB_PATH=/opt/flownative/lib \
    FLOWNATIVE_LOG_PATH=/opt/flownative/log \
    FLOWNATIVE_LOG_PATH_AND_FILENAME=/dev/stdout \
    LOGROTATE_BASE_PATH=/opt/flownative/logrotate \
    NGINX_BASE_PATH=/opt/flownative/nginx \
    LOG_DEBUG=false

USER root

# Packages are needed for the following reasons:
#
# bash              The entrypoint and library scripts are written in Bash
# ca-certificates   Up to date CA certificates for validation
# logrotate         Rotates the log files Nginx writes to FLOWNATIVE_LOG_PATH

RUN apk add --no-cache bash ca-certificates logrotate

COPY --from=envsubst-builder /out/envsubst /usr/local/bin/envsubst
COPY --from=module-builder /out.so /usr/lib/nginx/modules/ngx_http_headers_more_filter_module.so

COPY root-files /
RUN /build.sh && rm /build.sh

EXPOSE 8080

# terminate with SIGQUIT which is handled gracefully by nginx
# contrary to SIGTERM which terminates nginx immediately.
STOPSIGNAL SIGQUIT

USER nginx
ENTRYPOINT ["/entrypoint.sh"]
CMD [ "run" ]

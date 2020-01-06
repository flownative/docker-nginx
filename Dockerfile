FROM flownative/base:1
MAINTAINER Robert Lemke <robert@flownative.com>

# -----------------------------------------------------------------------------
# Nginx
# Latest versions: https://packages.ubuntu.com/bionic/nginx

ARG NGINX_VERSION
ENV NGINX_VERSION ${NGINX_VERSION}

# Create the beach user and group
RUN groupadd -r -g 1000 beach && \
    useradd -s /bin/bash -r -g beach -G beach -p "*" -u 1000 beach && \
    rm -f /var/log/* /etc/group~ /etc/gshadow~

# Note: we need nginx-extras for the chunkin and more headers module and apache2-utils for the htpasswd command
RUN apt-get update \
    && apt-get install \
        nginx-common=${NGINX_VERSION} \
        nginx-extras=${NGINX_VERSION} \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/log/apt \
    && rm -rf /var/log/dpkg.log \
    && rm -rf /var/www \
    && rm /etc/nginx/sites-available/default \
    && rm /etc/nginx/sites-enabled/default

# Forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

COPY service-nginx.sh /etc/service/nginx/run
RUN chmod 755 /etc/service/nginx/run \
    && chown root:root /etc/service/nginx/run
COPY nginx.conf /etc/nginx/nginx.conf
COPY mime.types /etc/nginx/

EXPOSE 80

FROM eu.gcr.io/flownative-beach/base:0.9.22-6
MAINTAINER Robert Lemke <robert@flownative.com>

RUN groupadd -r -g 1000 beach && useradd -s /bin/bash -r -g beach -G beach -p "*" -u 1000 beach

RUN apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62
RUN echo "deb http://nginx.org/packages/mainline/ubuntu/ trusty nginx" >> /etc/apt/sources.list

ENV NGINX_VERSION 1.9.15-0ubuntu1

# Note: we need nginx-extras for the chunkin and more headers module and apache2-utils for the htpasswd command
RUN apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests \
        ca-certificates \
        nginx-common=${NGINX_VERSION} \
        nginx-extras=${NGINX_VERSION} \
        apache2-utils \
    && rm -rf /var/lib/apt/lists/* \
    && rm /etc/nginx/sites-available/default \
    && rm /etc/nginx/sites-enabled/default

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

COPY service-nginx.sh /etc/service/nginx/run
RUN chmod 755 /etc/service/nginx/run \
    && chown root:root /etc/service/nginx/run
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

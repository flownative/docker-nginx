[![MIT license](http://img.shields.io/badge/license-MIT-brightgreen.svg)](http://opensource.org/licenses/MIT)
[![Maintenance level: Love](https://img.shields.io/badge/maintenance-%E2%99%A1%E2%99%A1%E2%99%A1-ff69b4.svg)](https://www.flownative.com/en/products/open-source.html)
![Nightly Builds](https://github.com/flownative/docker-nginx/workflows/Nightly%20Builds/badge.svg)
![Release to Docker Registries](https://github.com/flownative/docker-nginx/workflows/Release%20to%20Docker%20Registries/badge.svg)

# Flownative Nginx Image

A Docker image providing [Nginx](https://nginx.org) for [Beach](https://www.flownative.com/beach),
[Local Beach](https://www.flownative.com/localbeach) and other purposes. Compared to other
Nginx images, this one provides specific features which come in handy for running a
[Neos CMS](https://www.neos.io) instance or Neos Flow application.

## tl;dr

```bash
$ docker run flownative/nginx
```

## Hosting a Neos website or Flow application

tbd.

## Hosting a static website

tbd.

## Configuration

### Logging

By default, the access log is written to STDOUT and the error log is
redirected to STDERR. That way, you can follow logs by watching
container logs with `docker logs` or using a similar mechanism in
Kubernetes or your actual platform.

The log level for error can be defined via the `NGINX_LOG_LEVEL`
environment variable. See the
[Nginx documentation](https://docs.nginx.com/nginx/admin-guide/monitoring/logging/)
for possible values. The default value is `warn`.

### Environment variables

| Variable Name                  | Type    | Default                               | Description                                                                                         |
|:-------------------------------|:--------|:--------------------------------------|:----------------------------------------------------------------------------------------------------|
| NGINX_BASE_PATH                | string  | /opt/flownative/nginx                 | Base path for Nginx                                                                                 |
| NGINX_LOG_LEVEL                | string  | warn                                  | Nginx log level (see [documentation](https://docs.nginx.com/nginx/admin-guide/monitoring/logging/)) |
| NGINX_CACHE_ENABLE             | boolean | no                                    | If the FastCGI cache should be enabled; see section about caching                                   |
| NGINX_CACHE_NAME               | string  | application                           | Name of the memory zone Nginx should use for caching                                                |
| NGINX_CACHE_DEFAULT_LIFETIME   | string  | 5s                                    | Default cache lifetime to use when caching is enabled                                               |
| NGINX_CACHE_MAX_SIZE           | string  | 1024m                                 | Maximum memory size for the FastCGI cache                                                           |
| NGINX_CACHE_INACTIVE           | string  | 1h                                    | Time after which cache entries are removed automatically                                            |
| NGINX_CACHE_USE_STALE_OPTIONS  | string  | updating error timeout invalid_header | Options to pass to the `fastcgi_cache_use_stale` directive                                          |
| NGINX_CACHE_BACKGROUND_UPDATE  | boolean | off                                   | If background updates should be enabled                                                             |
| NGINX_CUSTOM_ERROR_PAGE_CODES  | string  | 500 501 502 503                       | FastCGI error codes which should redirect to the custom error page                                  |
| NGINX_CUSTOM_ERROR_PAGE_TARGET | string  |                                       | Upstream URL to use for custom FastCGI error pages                                                  |


## Security aspects

This image is designed to run as a non-root container. Using an
unprivileged user generally improves the security of an image, but may
have a few side-effects, especially when you try to debug something by
logging in to the container using `docker exec`.

When you are running this image with Docker or in a Kubernetes context,
you can take advantage of the non-root approach by disallowing privilege
escalation:

```yaml
$ docker run flownative/nginx:latest --security-opt=no-new-privileges
```

When you exec into this container running bash, you will notice your
prompt claiming "I have no name!". That's nothing to worry about: The
container runs as a user with uid 1000, but in fact that user does not
even exist. Some platforms will even assign a random uid, so it wouldn't
be feasible to create a named user for that purpose:

```
$ docker run -ti --name nginx --rm flownative/nginx:latest bash
I have no name!@5a0adf17e426:/$ whoami
whoami: cannot find name for user ID 1000
```

Because Nginx runs as a non-root user, it cannot bind to port 80 and
users port 8080 instead. Since you can map that port to any other port
by telling Docker or Kubernetes, this won't be a problem in practice.
However, be aware that you need to specify 8080 as the container port –
otherwise you won't get a connection.

## Building this image

Build this image with `docker build`. You need to specify the desired
version for some of the tools as build arguments:

```bash
docker build \
    --build-arg NGINX_VERSION=1.14.2-2+deb10u1 \
    -t flownative/nginx:latest .
```

Check the latest stable release on the tool's respective websites:

- Nginx: https://packages.debian.org/buster/nginx

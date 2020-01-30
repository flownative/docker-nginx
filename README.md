[![MIT license](http://img.shields.io/badge/license-MIT-brightgreen.svg)](http://opensource.org/licenses/MIT)
[![Maintenance level: Love](https://img.shields.io/badge/maintenance-%E2%99%A1%E2%99%A1%E2%99%A1-ff69b4.svg)](https://www.flownative.com/en/products/open-source.html)
![Nightly Builds](https://github.com/flownative/docker-nginx/workflows/Nightly%20Builds/badge.svg)
![Release to Docker Registries](https://github.com/flownative/docker-nginx/workflows/Release%20to%20Docker%20Registries/badge.svg)

# Flownative Nginx Image

A Docker image providing [Nginx](https://nginx.org) for [Beach](https://www.flownative.com/beach),
[Local Beach](https://www.flownative.com/localbeach) and other purposes. Compared to other
Nginx images, this one provides specific features which come in handy for running a
[Neos CMS](https://www.neos.io) instance.

## tl;dr;

```bash
$ docker run --name nginx flownative/nginx:latest
```

## Hosting a Neos website

tbd.

## Hosting a static website

tbd.

## Configuration

tbd.

## Security aspects

This image is designed to run as a non-root container. Using an unprivileged user generally
improves the security of an image, but may have a few side-effects, especially when you try
to debug something by logging in to the container using `docker exec`.

When you are running this image with Docker or in a Kubernetes context, you can take advantage
of the non-root approach by disallowing privilege escalation:

```yaml
$ docker run --name nginx flownative/nginx:latest --security-opt=no-new-privileges 
``` 

When you exec into this container running bash, you will notice your prompt claiming
"I have no name!". That's nothing to worry about: The container runs as a user with
uid 1000, but in fact that user does not even exist. Some platforms will even assign
a random uid, so it wouldn't be feasible to create a named user for that purpose:

```
$ docker run -ti --name nginx --rm flownative/nginx:latest bash  
I have no name!@5a0adf17e426:/$ whoami
whoami: cannot find name for user ID 1000
```

## Building this image

Build this image with `docker build`. You need to specify the desired version for some
of the tools as build arguments:

```bash
docker build \
    --build-arg NGINX_VERSION=1.14.2-2+deb10u1 \
    -t flownative/nginx:latest .
```

Check the latest stable release on the tool's respective websites:
 
- Nginx: https://packages.debian.org/buster/nginx

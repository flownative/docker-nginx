# Flownative Beach Nginx Image

A Docker image providing Nginx for [Beach](https://www.flownative.com/beach) and [Local Beach](https://www.flownative.com/localbeach).

## Building this image

Build this image with `docker build`. You need to specify the desired version for some
of the tools as build arguments:

```bash
docker build \
    --build-arg NGINX_VERSION=1.14.0-0ubuntu1.6 \
    -t flownative/beach-nginx:latest .
```

Check the latest stable release on the tool's respective websites:
 
- Nginx: https://packages.ubuntu.com/bionic/nginx
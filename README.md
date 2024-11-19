[![MIT license](http://img.shields.io/badge/license-MIT-brightgreen.svg)](http://opensource.org/licenses/MIT)
[![Maintenance level: Love](https://img.shields.io/badge/maintenance-%E2%99%A1%E2%99%A1%E2%99%A1-ff69b4.svg)](https://www.flownative.com/en/products/open-source.html)
![Build Docker Image daily](https://github.com/flownative/docker-nginx/actions/workflows/docker.build.yaml/badge.svg)
![Build Docker Image on tag](https://github.com/flownative/docker-nginx/actions/workflows/docker.build.onpush.yaml/badge.svg)
# Flownative Nginx Image

A Docker image providing [Nginx](https://nginx.org)
for [Beach](https://www.flownative.com/beach),
[Local Beach](https://www.flownative.com/localbeach) and other purposes.
Compared to other
Nginx images, this one provides specific features which come in handy for
running a
[Neos CMS](https://www.neos.io) instance or Neos Flow application.

## tl;dr

```bash
$ docker run flownative/nginx
```

## Hosting a Neos website or Flow application

tbd.

## Hosting a static website

Set the environment variable "BEACH_NGINX_MODE" to "Static" and
optionally set the variable "NGINX_STATIC_ROOT" to the path leading to
the root of your static site.

The BEACH_NGINX_MODE variable follows legacy naming and will be renamed
/ replaced by another concept in the future.

## Configuration

### Logging

By default, the access log is written to STDOUT, and the error log is
redirected to STDERR. That way, you can follow logs by watching
container logs with `docker logs` or using a similar mechanism in
Kubernetes or your actual platform.

Additionally, logs are also stored in /opt/flownative/log/nginx-error.log
and /opt/flownative/log/nginx-access.log. If the log format is "json",
the access log file is /opt/flownative/log/nginx-access.json.log

Note that the error log only contains errors related to the webserver itself.
Requests resulting in status codes like 404 (not found) or 503 (internal
server error) are logged to the access log, if it is enabled.

The log level for the error log can be defined via the `NGINX_LOG_LEVEL`
environment variable. See the
[Nginx documentation](https://docs.nginx.com/nginx/admin-guide/monitoring/logging/)
for possible values. The default value is `warn`.

The access log is disabled by default, it can be enabled by setting
`NGINX_ACCESS_LOG_ENABLE` to "true".

The access log's default format is similar to the standard Nginx
"combined" format with a few additions, so that the IP address of
the original request is shown since this Nginx is usually operated
behind a reverse proxy.

Instead of the default format, a JSON format can be used by setting
`NGINX_ACCESS_LOG_FORMAT` to "json".

The access log may contain a lot of entries, if enabled. If you are only
interested in requests resulting in certain status codes (for example
internal server errors), you can define a regular expression which filters out
other log entries. Setting `NGINX_ACCESS_LOG_IGNORED_STATUS_CODES_REGEX` to
"^[234]" will ignore all responses whose status code starts with "2", "3" or
"4" respectively. Therefore, only 5xx errors will then end up in the access
log.

By default, connection-related status (1xx) and redirects (3xx) will be ignored.

NOTE: Be careful when specifying the regular expression, because syntax
errors might keep Nginx from starting.

### Environment variables

| Variable Name                               | Type    | Default                               | Description                                                                                                                                                                                                       |
|:--------------------------------------------|:--------|:--------------------------------------|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| NGINX_BASE_PATH                             | string  | /opt/flownative/nginx                 | Base path for Nginx                                                                                                                                                                                               |
| NGINX_ERROR_LOG_LEVEL                       | string  | warn                                  | Nginx log level (see [documentation](https://docs.nginx.com/nginx/admin-guide/monitoring/logging/))                                                                                                               |
| NGINX_ACCESS_LOG_ENABLE                     | boolean | no                                    | Nginx log level (see [documentation](https://docs.nginx.com/nginx/admin-guide/monitoring/logging/))                                                                                                               |
| NGINX_ACCESS_LOG_FORMAT                     | string  | default                               | Format of the access log; possible values are "default" and "json"                                                                                                                                                |
| NGINX_ACCESS_LOG_MODE                       | string  | dynamic                               | Defines which requests should be logged: "dynamic" only logs dynamic requests to PHP, "all" also includes requests to static files                                                                                |
| NGINX_ACCESS_LOG_IGNORED_STATUS_CODES_REGEX | string  | ^[13]                                 | Regular expression which defines which status codes should NOT be logged into the access log                                                                                                                      |
| NGINX_CACHE_ENABLE                          | boolean | no                                    | If the FastCGI cache should be enabled; see section about caching                                                                                                                                                 |
| NGINX_CACHE_NAME                            | string  | application                           | Name of the memory zone Nginx should use for caching                                                                                                                                                              |
| NGINX_CACHE_DEFAULT_LIFETIME                | string  | 5s                                    | Default cache lifetime to use when caching is enabled                                                                                                                                                             |
| NGINX_CACHE_MAX_SIZE                        | string  | 1024m                                 | Maximum memory size for the FastCGI cache                                                                                                                                                                         |
| NGINX_CACHE_INACTIVE                        | string  | 1h                                    | Time after which cache entries are removed automatically                                                                                                                                                          |
| NGINX_CACHE_USE_STALE_OPTIONS               | string  | updating error timeout invalid_header | Options to pass to the `fastcgi_cache_use_stale` directive                                                                                                                                                        |
| NGINX_CACHE_BACKGROUND_UPDATE               | boolean | off                                   | If background updates should be enabled                                                                                                                                                                           |
| NGINX_CUSTOM_ERROR_PAGE_CODES               | string  | 500 501 502 503                       | FastCGI error codes which should redirect to the custom error page; codes are separated by spaces                                                                                                                 |
| NGINX_CUSTOM_ERROR_PAGE_TARGET              | string  |                                       | Upstream URL to use for custom FastCGI error pages, for example https://example.com/maintenance.html                                                                                                              |
| NGINX_CUSTOM_LOCATION_BLOCK_BASE64          | string  |                                       | Base64-encoded Nginx location block to include in the server configuration. The block will be included in the server configuration before the default location block. Be careful!                                 |
| NGINX_STATIC_ROOT                           | string  | /var/www/html                         | Document root path for when BEACH_NGINX_MODE is "Static"                                                                                                                                                          |
| NGINX_STRICT_TRANSPORT_SECURITY_ENABLE      | boolean | no                                    | If Strict-Transport-Security headers should be sent (HSTS)                                                                                                                                                        |
| NGINX_STRICT_TRANSPORT_SECURITY_PRELOAD     | boolean | no                                    | If site should be added to list of HTTPS-only sites by Google and others                                                                                                                                          |
| NGINX_STRICT_TRANSPORT_SECURITY_MAX_AGE     | boolean | 31536000                              | Maxmimum age for Strict-Transport-Security header, if enabled                                                                                                                                                     |
| NGINX_AUTH_BASIC_REALM                      | string  | off                                   | Realm for HTTP Basic Authentication; if "off", authentication is disabled                                                                                                                                         |
| NGINX_AUTH_BASIC_USERNAME                   | string  |                                       | Username for HTTP Basic Authentication                                                                                                                                                                            |
| NGINX_AUTH_BASIC_ENCODED_HASHED_PASSWORD    | string  |                                       | Base64-encoded hashed password (using httpasswd) for HTTP Basic Authentication                                                                                                                                    |
| NGINX_ENABLE_UNDERSCORES_IN_HEADERS         | boolean | no                                    | Enables or disables the use of underscores in client request header fields.                                                                                                                                       |
| BEACH_NGINX_CUSTOM_METRICS_ENABLE           | boolean | no                                    | If support for a custom metrics endpoint should be enabled                                                                                                                                                        |
| BEACH_NGINX_CUSTOM_METRICS_SOURCE_PATH      | string  | /metrics                              | Path where metrics are located                                                                                                                                                                                    |
| BEACH_NGINX_CUSTOM_METRICS_TARGET_PORT      | integer | 8082                                  | Port at which Nginx should listen to provide the metrics for scraping                                                                                                                                             |
| BEACH_NGINX_MODE                            | string  | Flow                                  | Either "Flow" or "Static"; this variable is going to be renamed in the future                                                                                                                                     |
| BEACH_ASSET_PROXY_ENDPOINT                  | string  |                                       | Endpoint of a cloud storage frontend to use for proxying requests to Flow persistent resources. Requires BEACH_PERSISTENT_RESOURCES_BASE_PATH to be set. Example: "https://assets.flownative.com/example-bucket/" |
| BEACH_ASSET_PROXY_RESOLVER                  | string  | 8.8.8.8                               | IP address of a DNS server to use for resolving domains when proxying assets. Set this to 127.0.0.11 when using Local Beach.                                                                                      |
| BEACH_PERSISTENT_RESOURCES_BASE_PATH        | string  |                                       | Base path of URLs pointing to Flow persistent resources; example: "https://www.flownative.com/assets/"                                                                                                            |
| BEACH_STATIC_RESOURCES_LIFETIME             | string  | 30d                                   | Expiration time for static resources; examples: "3600s" or "7d" or "max"                                                                                                                                          |
| FLOW_HTTP_TRUSTED_PROXIES                   | string  | 10.0.0.0/8                            | Nginx passes FLOW_HTTP_TRUSTED_PROXIES to the virtual host using the value of this variable                                                                                                                       |

## Asset Proxy

By default, the direct URL of an asset stored in the cloud storage is used as
part of the Flow or Neos frontend output. In order to make URLs more
user-friendly or hide the fact that assets are stored in a cloud storage,
Nginx can act as a reverse proxy and make assets available through a
sub-path of the website's main domain.

For example, if the website is reachable via "https://www.example.com", the
proxy can be configured to map the path "https://www.example.com/assets/" to
assets stored in a cloud storage bucket which is accessible at
"https://some.cloud.storage/some-bucket/".

The environment variables to set for the above example are as follows:

```
BEACH_PERSISTENT_RESOURCES_BASE_PATH=/assets/
BEACH_ASSET_PROXY_ENDPOINT=https://some.cloud.storage/some-bucket
```

> Note: Make sure that both values are formatted exactly like in the given
> examples, for example don't forget the trailing "/" in
> `BEACH_PERSISTENT_RESOURCES_BASE_PATH` and don't add a trailing "/" in
> "BEACH_ASSET_PROXY_ENDPOINT".

## Security aspects

This image is designed to run as a non-root container. Using an
unprivileged user generally improves the security of an image, but may
have a few side effects, especially when you try to debug something by
logging in to the container using `docker exec`.

When you are running this image with Docker or in a Kubernetes context,
you can take advantage of the non-root approach by disallowing privilege
escalation:

```yaml
$ docker run flownative/nginx:latest --security-opt=no-new-privileges
```

Because Nginx runs as a non-root user, it cannot bind to port 80 and
users port 8080 instead. Since you can map that port to any other port
by telling Docker or Kubernetes, this won't be a problem in practice.
However, be aware that you need to specify 8080 as the container port –
otherwise you won't get a connection.

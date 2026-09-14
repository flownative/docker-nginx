#!/usr/bin/env bash
# Shared helpers and the environment variable matrix for all tests.
# Sourced by the individual scripts, not meant to be run directly.

# The image under test, and the one it is compared against.
CANDIDATE_IMAGE="${CANDIDATE_IMAGE:-flownative/nginx:local}"
REFERENCE_IMAGE="${REFERENCE_IMAGE:-harbor.flownative.io/docker/nginx:5.0.1}"
PHP_IMAGE="${PHP_IMAGE:-flownative/beach-php:8.5}"

# Each line: <name>|<KEY=VALUE>;<KEY=VALUE>...
# The semicolon separates the variables, so that values may contain spaces
# (for example NGINX_CUSTOM_ERROR_PAGE_CODES="502 503").
#
# The matrix covers every variable documented in README.md, plus the
# undocumented ones which influence the generated configuration.
# shellcheck disable=SC2034  # used by the sourcing scripts
read -r -d '' MATRIX <<'EOF' || true
default|
static|BEACH_NGINX_MODE=Static
static-root|BEACH_NGINX_MODE=Static;NGINX_STATIC_ROOT=/usr/share/nginx/html
cache|NGINX_CACHE_ENABLE=true
cache-tuned|NGINX_CACHE_ENABLE=true;NGINX_CACHE_NAME=mysite;NGINX_CACHE_DEFAULT_LIFETIME=30s;NGINX_CACHE_BACKGROUND_UPDATE=on
cache-stale|NGINX_CACHE_ENABLE=true;NGINX_CACHE_USE_STALE_OPTIONS=error timeout
cache-inactive|NGINX_CACHE_ENABLE=true;NGINX_CACHE_INACTIVE=12h
cache-resources|NGINX_CACHE_RESOURCES_MAX_SIZE=5g;NGINX_CACHE_MAX_SIZE=512m
asset-proxy|BEACH_ASSET_PROXY_ENDPOINT=https://assets.example.com/bucket;BEACH_PERSISTENT_RESOURCES_BASE_PATH=/assets/
asset-proxy-resolver|BEACH_ASSET_PROXY_ENDPOINT=https://assets.example.com/bucket;BEACH_PERSISTENT_RESOURCES_BASE_PATH=/assets/;BEACH_ASSET_PROXY_RESOLVER=127.0.0.11
gcs|BEACH_GOOGLE_CLOUD_STORAGE_TARGET_BUCKET=my-bucket
fallback|BEACH_PERSISTENT_RESOURCES_FALLBACK_BASE_URI=https://old.example.com/
hsts|NGINX_STRICT_TRANSPORT_SECURITY_ENABLE=true
hsts-preload|NGINX_STRICT_TRANSPORT_SECURITY_ENABLE=true;NGINX_STRICT_TRANSPORT_SECURITY_PRELOAD=true;NGINX_STRICT_TRANSPORT_SECURITY_MAX_AGE=63072000
accesslog|NGINX_ACCESS_LOG_ENABLE=true
accesslog-json|NGINX_ACCESS_LOG_ENABLE=true;NGINX_ACCESS_LOG_FORMAT=json
accesslog-all|NGINX_ACCESS_LOG_ENABLE=true;NGINX_ACCESS_LOG_MODE=all
accesslog-filter|NGINX_ACCESS_LOG_ENABLE=true;NGINX_ACCESS_LOG_IGNORED_STATUS_CODES_REGEX=^[234]
basicauth|NGINX_AUTH_BASIC_REALM=Staging;NGINX_AUTH_BASIC_USERNAME=admin;NGINX_AUTH_BASIC_ENCODED_HASHED_PASSWORD=JGFwcjEkeHl6JGFiYw==
errorpage|NGINX_CUSTOM_ERROR_PAGE_TARGET=https://example.com/maintenance.html
errorpage-codes|NGINX_CUSTOM_ERROR_PAGE_TARGET=https://example.com/x.html;NGINX_CUSTOM_ERROR_PAGE_CODES=502 503
customblock|NGINX_CUSTOM_LOCATION_BLOCK_BASE64=bG9jYXRpb24gL2htIHsgcmV0dXJuIDIwNDsgfQo=
metrics|BEACH_NGINX_CUSTOM_METRICS_ENABLE=true
metrics-tuned|BEACH_NGINX_CUSTOM_METRICS_ENABLE=true;BEACH_NGINX_CUSTOM_METRICS_SOURCE_PATH=/prom;BEACH_NGINX_CUSTOM_METRICS_TARGET_PORT=9090
status-off|BEACH_NGINX_STATUS_ENABLE=false
status-port|BEACH_NGINX_STATUS_PORT=9111
fpm|BEACH_PHP_FPM_HOST=127.0.0.1;BEACH_PHP_FPM_PORT=9999
flowcontext|BEACH_FLOW_BASE_CONTEXT=Development;BEACH_FLOW_SUB_CONTEXT=Local
flowcontext-explicit|FLOW_CONTEXT=Development
trustedproxies|FLOW_HTTP_TRUSTED_PROXIES=192.168.0.0/16
apppath|BEACH_APPLICATION_PATH=/srv/app
underscores|NGINX_ENABLE_UNDERSCORES_IN_HEADERS=true
underscores-static|BEACH_NGINX_MODE=Static;NGINX_ENABLE_UNDERSCORES_IN_HEADERS=true
lifetime|NGINX_STATIC_FILES_LIFETIME=30d
workers|NGINX_WORKER_PROCESSES=4
errorloglevel|NGINX_ERROR_LOG_LEVEL=debug
loglevel|NGINX_LOG_LEVEL=debug
EOF

# ---------------------------------------------------------------------------
# env_to_docker_args() - Turns "K=V;K=V" into an array of -e arguments.
# The result ends up in the global variable DOCKER_ARGS.
#
env_to_docker_args() {
    local envspec="${1:-}"
    DOCKER_ARGS=()
    [ -z "${envspec}" ] && return 0
    local pair
    while IFS= read -r pair; do
        [ -z "${pair}" ] && continue
        DOCKER_ARGS+=(-e "${pair}")
    done < <(tr ';' '\n' <<<"${envspec}")
}

# ---------------------------------------------------------------------------
# Output helpers. Every script counts failures in the global variable FAILS.
#
FAILS=0

pass() { printf '  \033[32mok  \033[0m %-38s %s\n' "$1" "${2:-}"; }
fail() { printf '  \033[31mFAIL\033[0m %-38s %s\n' "$1" "${2:-}"; FAILS=$((FAILS + 1)); }

check_equals() { # name, actual, expected
    if [ "$2" = "$3" ]; then pass "$1" "$2"; else fail "$1" "expected=$3 got=$2"; fi
}

# For log lines: the exact number is not deterministic (Nginx retries failed
# upstreams, and the error log contains the request line as well). What matters
# is that the line shows up at all.
check_present() { # name, count
    if [ "${2:-0}" -ge 1 ]; then pass "$1" "found ${2}x"; else fail "$1" "not found"; fi
}

heading() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

require_image() {
    if ! docker image inspect "$1" >/dev/null 2>&1; then
        echo "  Image '$1' is missing locally, trying docker pull ..."
        docker pull -q "$1" >/dev/null 2>&1 || {
            echo "  ERROR: '$1' is not available."
            return 1
        }
    fi
}

wait_for_http() { # url, seconds
    local url="$1" max="${2:-15}"
    for _ in $(seq 1 $((max * 4))); do
        curl -sf -o /dev/null "${url}" 2>/dev/null && return 0
        sleep 0.25
    done
    return 1
}

# Like wait_for_http, but accepts any status code -- in Flow mode, Nginx
# returns 502 as long as there is no PHP-FPM behind it.
wait_for_port() { # url, seconds
    local url="$1" max="${2:-15}"
    for _ in $(seq 1 $((max * 4))); do
        [ "$(curl -s -o /dev/null -w '%{http_code}' "${url}" 2>/dev/null)" != "000" ] && return 0
        sleep 0.25
    done
    return 1
}

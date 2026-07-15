#!/usr/bin/env bash
# Gemeinsame Helfer und die Env-Variablen-Matrix für alle Tests.
# Wird von den einzelnen Skripten gesourct, nicht direkt ausgeführt.

# Das Image, das getestet wird, und die Referenz, gegen die verglichen wird.
CANDIDATE_IMAGE="${CANDIDATE_IMAGE:-flownative/nginx:local}"
REFERENCE_IMAGE="${REFERENCE_IMAGE:-harbor.flownative.io/docker/nginx:latest}"
PHP_IMAGE="${PHP_IMAGE:-flownative/beach-php:8.4}"

# Jede Zeile: <name>|<KEY=VALUE>;<KEY=VALUE>...
# Semikolon trennt die Variablen, damit Werte Leerzeichen enthalten dürfen
# (z.B. NGINX_CUSTOM_ERROR_PAGE_CODES="502 503").
#
# Die Matrix deckt jede Variable ab, die README.md dokumentiert, plus die
# undokumentierten, die das Verhalten steuern.
# shellcheck disable=SC2034  # wird von den sourcenden Skripten benutzt
read -r -d '' MATRIX <<'EOF' || true
default|
static|BEACH_NGINX_MODE=Static
static-root|BEACH_NGINX_MODE=Static;NGINX_STATIC_ROOT=/usr/share/nginx/html
cache|NGINX_CACHE_ENABLE=true
cache-tuned|NGINX_CACHE_ENABLE=true;NGINX_CACHE_NAME=mysite;NGINX_CACHE_DEFAULT_LIFETIME=30s;NGINX_CACHE_BACKGROUND_UPDATE=on
cache-stale|NGINX_CACHE_ENABLE=true;NGINX_CACHE_USE_STALE_OPTIONS=error timeout
cache-resources|NGINX_CACHE_RESOURCES_MAX_SIZE=5g;NGINX_CACHE_MAX_SIZE=512m
asset-proxy|BEACH_ASSET_PROXY_ENDPOINT=https://assets.example.com/bucket;BEACH_PERSISTENT_RESOURCES_BASE_PATH=/assets/
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
loglevel|NGINX_LOG_LEVEL=debug
EOF

# ---------------------------------------------------------------------------
# env_to_docker_args() - Wandelt "K=V;K=V" in ein -e-Argumentarray um.
# Ergebnis steht in der globalen Variable DOCKER_ARGS.
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
# Ausgabe-Helfer. Jedes Skript zählt Fehler in der globalen Variable FAILS.
#
FAILS=0

pass() { printf '  \033[32mok  \033[0m %-34s %s\n' "$1" "${2:-}"; }
fail() { printf '  \033[31mFAIL\033[0m %-34s %s\n' "$1" "${2:-}"; FAILS=$((FAILS + 1)); }

check_equals() { # name, actual, expected
    if [ "$2" = "$3" ]; then pass "$1" "$2"; else fail "$1" "erwartet=$3 bekommen=$2"; fi
}

# Für Logzeilen: die exakte Anzahl ist nicht deterministisch (Nginx wiederholt
# fehlgeschlagene Upstreams, und das error_log enthält die Request-Zeile
# ebenfalls). Entscheidend ist, dass die Zeile überhaupt auftaucht.
check_present() { # name, count
    if [ "${2:-0}" -ge 1 ]; then pass "$1" "${2}x vorhanden"; else fail "$1" "nicht gefunden"; fi
}

heading() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

require_image() {
    if ! docker image inspect "$1" >/dev/null 2>&1; then
        echo "  Image '$1' fehlt lokal, versuche docker pull ..."
        docker pull -q "$1" >/dev/null 2>&1 || {
            echo "  FEHLER: '$1' ist nicht verfügbar."
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

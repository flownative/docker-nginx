#!/usr/bin/env bash
#
# Really starts the image and fires real requests at it: serving files, the
# status endpoint, headers_more, logging.

set -o nounset
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=lib.sh
. ./lib.sh

C=rt-test
PORT=18080
SPORT=18081

cleanup() { docker rm -f "${C}" >/dev/null 2>&1 || true; }
trap cleanup EXIT

require_image "${CANDIDATE_IMAGE}" || exit 1

# -------------------------------------------------------------- Static mode
heading "Static mode: serves files"
cleanup
docker run -d --name "${C}" -p "${PORT}:8080" -p "${SPORT}:8081" \
    -e BEACH_NGINX_MODE=Static \
    -e NGINX_STATIC_ROOT=/usr/share/nginx/html \
    "${CANDIDATE_IMAGE}" >/dev/null
wait_for_http "http://localhost:${PORT}/" || fail "port did not come up"

check_equals "GET / returns 200" \
    "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/")" "200"
check_equals "Nginx welcome page is served" \
    "$(curl -s "http://localhost:${PORT}/" | grep -qc 'Welcome to nginx' && echo yes)" "yes"
check_equals "status endpoint on 8081" \
    "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${SPORT}/status")" "200"
check_equals "status endpoint: everything else denied" \
    "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${SPORT}/foo")" "403"
check_equals "dotfiles cannot be found" \
    "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/.env")" "404"

# ------------------------------------------------------------- headers_more
# None of the shipped configurations uses the module, but customers inject it
# through NGINX_CUSTOM_LOCATION_BLOCK_BASE64. Without this test, a missing or
# unloadable module would only show up at the customer.
heading "headers_more: module works at runtime"
cleanup
BLOCK=$(printf 'location /hm { more_set_headers "X-Test: ok"; return 204; }\n' | base64)
docker run -d --name "${C}" -p "${PORT}:8080" \
    -e NGINX_CUSTOM_LOCATION_BLOCK_BASE64="${BLOCK}" \
    "${CANDIDATE_IMAGE}" >/dev/null
wait_for_http "http://localhost:${PORT}/hm" || fail "port did not come up"
check_equals "more_set_headers sets the header" \
    "$(curl -s -D - -o /dev/null "http://localhost:${PORT}/hm" | grep -ci '^X-Test: ok')" "1"

# ------------------------------------------------------------------ Logging
# The access_log directive is only rendered in Flow mode (in static mode,
# NGINX_ACCESS_LOG_ENABLE has never had any effect), and there inside the PHP
# location block. Without PHP-FPM behind it, the request ends in a 502 -- which
# is enough for logging, because the default filter only hides 1xx and 3xx.
#
# Nginx writes to the files only. syslog-ng tails them and mirrors them to
# stdout, prefixed with "HH:MM:SS TZ HOST [LEVEL]". The JSON log only reaches
# the stream with SYSLOG_JSON=true, the text log only without it.
heading "Logging: file AND stream"
for fmt in default json; do
    cleanup
    syslog_json=false
    [ "${fmt}" = "json" ] && syslog_json=true
    docker run -d --name "${C}" -p "${PORT}:8080" \
        -e NGINX_ACCESS_LOG_ENABLE=true \
        -e NGINX_ACCESS_LOG_FORMAT="${fmt}" \
        -e SYSLOG_JSON="${syslog_json}" \
        "${CANDIDATE_IMAGE}" >/dev/null
    wait_for_port "http://localhost:${PORT}/" || fail "port did not come up"
    curl -s -o /dev/null "http://localhost:${PORT}/index.php"
    sleep 7  # wait for flush=5s plus syslog-ng's follow_freq(1)

    if [ "${fmt}" = "json" ]; then
        logfile=/opt/flownative/log/nginx-access.json.log
        pattern='"request_method": "GET"'
    else
        logfile=/opt/flownative/log/nginx-access.log
        pattern='"GET /index.php HTTP/1.1" 502'
    fi

    check_present "access log (${fmt}) in the stream" \
        "$(docker logs "${C}" 2>&1 | grep -c "${pattern}")"
    # This is the file the Promtail addon scrapes:
    check_present "access log (${fmt}) in the file" \
        "$(docker exec "${C}" sh -c "grep -c '${pattern}' ${logfile} 2>/dev/null" || echo 0)"
done

check_present "error log in the stream" \
    "$(docker logs "${C}" 2>&1 | grep -c 'connect() failed')"
check_present "error log in the file" \
    "$(docker exec "${C}" sh -c "grep -c 'connect() failed' /opt/flownative/log/nginx-error.log 2>/dev/null" || echo 0)"

heading "Result"
echo "  Failed: ${FAILS}"
exit "${FAILS}"

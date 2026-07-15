#!/usr/bin/env bash
#
# Startet das Image wirklich und schickt echte Requests dagegen:
# Auslieferung, Status-Endpoint, headers_more, Logging, Shutdown.

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

# --------------------------------------------------------------- Static-Mode
heading "Static-Mode: liefert Dateien aus"
cleanup
docker run -d --name "${C}" -p "${PORT}:8080" -p "${SPORT}:8081" \
    -e BEACH_NGINX_MODE=Static \
    -e NGINX_STATIC_ROOT=/usr/share/nginx/html \
    "${CANDIDATE_IMAGE}" >/dev/null
wait_for_http "http://localhost:${PORT}/" || fail "Port kam nicht hoch"

check_equals "GET / liefert 200" \
    "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/")" "200"
check_equals "Nginx-Willkommensseite wird geliefert" \
    "$(curl -s "http://localhost:${PORT}/" | grep -qc 'Welcome to nginx' && echo yes)" "yes"
check_equals "Status-Endpoint auf 8081" \
    "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${SPORT}/status")" "200"
check_equals "Status-Endpoint: alles andere verboten" \
    "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${SPORT}/foo")" "403"
check_equals "Dotfiles nicht auffindbar" \
    "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/.env")" "404"

# ------------------------------------------------------------- headers_more
# Das Modul wird von keiner mitgelieferten Config benutzt, Kunden schleusen es
# aber via NGINX_CUSTOM_LOCATION_BLOCK_BASE64 ein. Ohne diesen Test würde ein
# fehlgeschlagener Modul-Build erst beim Kunden auffallen.
heading "headers_more: selbstgebautes Modul wirkt zur Laufzeit"
cleanup
BLOCK=$(printf 'location /hm { more_set_headers "X-Test: ok"; return 204; }\n' | base64)
docker run -d --name "${C}" -p "${PORT}:8080" \
    -e NGINX_CUSTOM_LOCATION_BLOCK_BASE64="${BLOCK}" \
    "${CANDIDATE_IMAGE}" >/dev/null
sleep 2
check_equals "more_set_headers setzt den Header" \
    "$(curl -s -D - -o /dev/null "http://localhost:${PORT}/hm" | grep -ci '^X-Test: ok')" "1"

# ------------------------------------------------------------------ Logging
# Die access_log-Direktive wird nur im Flow-Mode gesetzt (im Static-Mode ist
# NGINX_ACCESS_LOG_ENABLE seit jeher wirkungslos), und dort im PHP-Location-
# Block. Ohne PHP-FPM dahinter ergibt der Request ein 502 -- fürs Logging
# genügt das, da der Default-Filter nur 1xx/3xx ausblendet.
heading "Logging: Datei UND Stream"
for fmt in default json; do
    cleanup
    docker run -d --name "${C}" -p "${PORT}:8080" \
        -e NGINX_ACCESS_LOG_ENABLE=true \
        -e NGINX_ACCESS_LOG_FORMAT="${fmt}" \
        "${CANDIDATE_IMAGE}" >/dev/null
    sleep 2
    curl -s -o /dev/null "http://localhost:${PORT}/index.php"
    sleep 6  # flush=5s abwarten

    if [ "${fmt}" = "json" ]; then
        logfile=/opt/flownative/log/nginx-access.json.log
        pattern='"request_method": "GET"'
    else
        logfile=/opt/flownative/log/nginx-access.log
        pattern='"GET /index.php HTTP/1.1" 502'
    fi

    check_present "Access-Log (${fmt}) auf stdout" \
        "$(docker logs "${C}" 2>/dev/null | grep -c "${pattern}")"
    # Das ist die Datei, die das Promtail-Addon scrapt:
    check_present "Access-Log (${fmt}) in der Datei" \
        "$(docker exec "${C}" sh -c "grep -c '${pattern}' ${logfile} 2>/dev/null" || echo 0)"
done

check_present "error_log auf stderr" \
    "$(docker logs "${C}" 2>&1 >/dev/null | grep -c 'connect() failed')"
check_equals "error_log NICHT auf stdout" \
    "$(docker logs "${C}" 2>/dev/null | grep -c 'connect() failed')" "0"
check_present "error_log in der Datei" \
    "$(docker exec "${C}" sh -c "grep -c 'connect() failed' /opt/flownative/log/nginx-error.log 2>/dev/null" || echo 0)"

# ----------------------------------------------------------------- Shutdown
heading "Shutdown: SIGQUIT kommt bei Nginx als PID 1 an"
cleanup
docker run -d --name "${C}" -p "${PORT}:8080" -e BEACH_NGINX_MODE=Static "${CANDIDATE_IMAGE}" >/dev/null
wait_for_http "http://localhost:${PORT}/" || true
check_equals "Nginx ist PID 1" "$(docker exec "${C}" cat /proc/1/comm 2>/dev/null)" "nginx"

start=$(date +%s)
docker stop "${C}" >/dev/null
elapsed=$(( $(date +%s) - start ))
if [ "${elapsed}" -lt 5 ]; then
    pass "docker stop beendet graceful" "${elapsed}s (kein 10s-Timeout)"
else
    fail "docker stop" "${elapsed}s -- Signal kam nicht an"
fi

heading "Ergebnis"
echo "  Fehlgeschlagen: ${FAILS}"
exit "${FAILS}"

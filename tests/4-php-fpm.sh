#!/usr/bin/env bash
#
# End-to-End gegen das echte Beach-PHP-Image, inklusive Startup-Rennen.
#
# Hintergrund: Wird BEACH_PHP_FPM_HOST auf einen Namen gesetzt, der zu mehreren
# Adressen auflöst (localhost -> ::1 + 127.0.0.1), baut Nginx daraus eine
# implizite Upstream-Gruppe. Gruppen machen passive Health-Checks: eine einzige
# abgelehnte Verbindung -- die Warmup-Probe, bevor PHP-FPM lauscht, genügt --
# markiert beide Adressen für fail_timeout als tot, und danach liefert Nginx
# "no live upstreams", obwohl PHP-FPM längst bereit ist.
#
# Der Test erzeugt genau dieses Rennen absichtlich.

set -o nounset
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=lib.sh
. ./lib.sh

CN=e2e-nginx
CP=e2e-php
PORT=18094

cleanup() { docker rm -f "${CN}" "${CP}" >/dev/null 2>&1 || true; }
trap cleanup EXIT

require_image "${CANDIDATE_IMAGE}" || exit 1
require_image "${PHP_IMAGE}" || exit 1

heading "End-to-End: Nginx + PHP-FPM (${PHP_IMAGE})"
cleanup

docker run -d --name "${CN}" -p "${PORT}:8080" \
    -e NGINX_ACCESS_LOG_ENABLE=true "${CANDIDATE_IMAGE}" >/dev/null
sleep 3

echo "  1) Requests, WÄHREND PHP-FPM noch fehlt (erzeugt connect-Fehler):"
for _ in 1 2 3; do
    printf '       HTTP %s\n' "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/probe.php")"
done

echo "  2) PHP-FPM startet (im selben Netzwerk-Namespace, wie im Beach-Pod) ..."
docker run -d --name "${CP}" --network "container:${CN}" "${PHP_IMAGE}" >/dev/null 2>&1
for _ in $(seq 1 30); do
    docker exec "${CN}" sh -c 'netstat -ltn 2>/dev/null | grep -q ":9000"' && break
    sleep 2
done
docker exec "${CP}" sh -c 'mkdir -p /application/Web && echo "<?php echo \"PHP-OK\";" > /application/Web/probe.php'
sleep 2

echo "  3) Request, nachdem PHP-FPM bereit ist -- der entscheidende Teil:"
body=$(curl -s "http://localhost:${PORT}/probe.php")
code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/probe.php")
sleep 6

echo
check_equals "Nginx erholt sich, sobald PHP-FPM da ist" "${code}" "200"
check_equals "PHP-Antwort kommt durch" "${body}" "PHP-OK"
check_equals "kein 'no live upstreams'" \
    "$(docker logs "${CN}" 2>&1 | grep -c 'no live upstreams')" "0"
check_equals "genau eine Upstream-Adresse" \
    "$(docker logs "${CN}" 2>&1 | grep -o 'ua="[^"]*"' | tail -1)" 'ua="127.0.0.1:9000"'

heading "Ergebnis"
echo "  Fehlgeschlagen: ${FAILS}"
exit "${FAILS}"

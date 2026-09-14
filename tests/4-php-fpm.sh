#!/usr/bin/env bash
#
# End-to-end against the real Beach PHP image, including the startup race.
#
# Background: if BEACH_PHP_FPM_HOST is set to a name which resolves to several
# addresses (localhost -> ::1 + 127.0.0.1), Nginx turns them into an implicit
# upstream group. Groups do passive health checks: a single refused connection
# -- the warmup probe before PHP-FPM listens is enough -- marks both addresses
# as down for fail_timeout, and Nginx then answers with "no live upstreams"
# although PHP-FPM has long been ready.
#
# This test provokes exactly that race.

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

heading "End-to-end: Nginx + PHP-FPM (${PHP_IMAGE})"
cleanup

docker run -d --name "${CN}" -p "${PORT}:8080" \
    -e NGINX_ACCESS_LOG_ENABLE=true "${CANDIDATE_IMAGE}" >/dev/null
wait_for_port "http://localhost:${PORT}/" || fail "port did not come up"

echo "  1) Requests WHILE PHP-FPM is still missing (provokes connect errors):"
for _ in 1 2 3; do
    printf '       HTTP %s\n' "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/probe.php")"
done

echo "  2) PHP-FPM starts up (in the same network namespace, as in a Beach pod) ..."
docker run -d --name "${CP}" --network "container:${CN}" "${PHP_IMAGE}" >/dev/null 2>&1
for _ in $(seq 1 30); do
    docker exec "${CN}" bash -c ': </dev/tcp/127.0.0.1/9000' 2>/dev/null && break
    sleep 2
done
docker exec "${CP}" sh -c 'mkdir -p /application/Web && echo "<?php echo \"PHP-OK\";" > /application/Web/probe.php'
sleep 2

echo "  3) Request after PHP-FPM is ready -- the decisive part:"
body=$(curl -s "http://localhost:${PORT}/probe.php")
code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/probe.php")
sleep 6

echo
check_equals "Nginx recovers once PHP-FPM is there" "${code}" "200"
check_equals "PHP response comes through" "${body}" "PHP-OK"
check_equals "no 'no live upstreams'" \
    "$(docker logs "${CN}" 2>&1 | grep -c 'no live upstreams')" "0"
check_equals "exactly one upstream address" \
    "$(docker logs "${CN}" 2>&1 | grep -o 'ua="[^"]*"' | tail -1)" 'ua="127.0.0.1:9000"'

heading "Result"
echo "  Failed: ${FAILS}"
exit "${FAILS}"

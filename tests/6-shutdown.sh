#!/usr/bin/env bash
#
# Checks that "docker stop" shuts Nginx down gracefully.
#
# STOPSIGNAL is SIGQUIT, and it is delivered to PID 1 -- which is entrypoint.sh,
# not Nginx. If the entrypoint ignores the signal, Docker kills the container
# after its timeout. If supervisord passes it on as SIGTERM, Nginx only does a
# "fast" shutdown and drops open connections immediately.
#
# The test therefore keeps a throttled download open during the stop: only a
# graceful shutdown lets it finish.

set -o nounset
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=lib.sh
. ./lib.sh

C=sd-test
PORT=18096
SIZE=1500000
DOWNLOAD="${TMPDIR:-/tmp}/nginx-shutdown-test.$$"

cleanup() { docker rm -f "${C}" >/dev/null 2>&1 || true; rm -f "${DOWNLOAD}"; }
trap cleanup EXIT

require_image "${CANDIDATE_IMAGE}" || exit 1

heading "Shutdown: docker stop ends Nginx gracefully"
cleanup

# At 200 KB/s the download takes several seconds. It has to run considerably
# longer than the signal needs to reach Nginx: the entrypoint only reacts after
# its "sleep 1.1", and supervisorctl does not start instantly. Otherwise the
# download is done before Nginx could drop anything at all.
BLOCK=$(printf 'location = /slow { alias /tmp/slow.bin; limit_rate 200k; }\n' | base64)
docker run -d --name "${C}" -p "${PORT}:8080" \
    -e NGINX_CUSTOM_LOCATION_BLOCK_BASE64="${BLOCK}" \
    "${CANDIDATE_IMAGE}" >/dev/null
docker exec "${C}" sh -c "head -c ${SIZE} /dev/zero > /tmp/slow.bin"
wait_for_port "http://localhost:${PORT}/" || fail "port did not come up"

curl -s -o "${DOWNLOAD}" "http://localhost:${PORT}/slow" &
curl_pid=$!
sleep 1

# A generous timeout, so that it does not cut a graceful shutdown short.
# Whether the signal arrived is then shown by the exit code: 137 means Docker
# killed the container.
start=$(date +%s)
docker stop -t 30 "${C}" >/dev/null
elapsed=$(( $(date +%s) - start ))

wait "${curl_pid}"
curl_rc=$?

check_equals "container exits regularly (not killed)" \
    "$(docker inspect -f '{{.State.ExitCode}}' "${C}")" "0"
check_equals "running download is served to the end" \
    "${curl_rc}/$(wc -c < "${DOWNLOAD}" | tr -d ' ')" "0/${SIZE}"
check_present "entrypoint says good bye" \
    "$(docker logs "${C}" 2>&1 | grep -c 'Good bye')"
echo "  (docker stop took ${elapsed}s)"

heading "Result"
echo "  Failed: ${FAILS}"
exit "${FAILS}"

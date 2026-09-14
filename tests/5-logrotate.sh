#!/usr/bin/env bash
#
# Checks that the log files are rotated -- without rotation, the log volume
# Nginx shares with the Promtail addon fills up.
#
# In the image, logrotate-cron.sh (run by supervisord) only calls logrotate
# when the current minute is divisible by five. Waiting for that takes too
# long, so this test performs exactly that call itself. What it checks is the
# configuration, including postrotate: Nginx has to write to the new file
# afterwards, not to the rotated one.
#
# Careful when changing this: "maxsize 50M" means 52,428,800 bytes. A file of
# 52,000,000 bytes does NOT trigger the rotation.

set -o nounset
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=lib.sh
. ./lib.sh

C=lr-test
PORT=18095
MAXSIZE_BYTES=52428800

cleanup() { docker rm -f "${C}" >/dev/null 2>&1 || true; }
trap cleanup EXIT

require_image "${CANDIDATE_IMAGE}" || exit 1

heading "Logrotate"
cleanup
docker run -d --name "${C}" -p "${PORT}:8080" "${CANDIDATE_IMAGE}" >/dev/null
wait_for_port "http://localhost:${PORT}/" || fail "port did not come up"

check_present "logrotate-cron.sh is running" \
    "$(docker exec "${C}" sh -c 'ps -eo args | grep -c "^/bin/bash .*logrotate-cron.sh"' || echo 0)"

echo "  Growing the error log beyond maxsize ($((MAXSIZE_BYTES + 2000000)) bytes) ..."
docker exec "${C}" sh -c "head -c $((MAXSIZE_BYTES + 2000000)) /dev/zero | tr '\\0' 'x' >> /opt/flownative/log/nginx-error.log"

echo "  Calling logrotate the way logrotate-cron.sh does ..."
docker exec "${C}" bash -c '"${LOGROTATE_BASE_PATH}/sbin/logrotate" "--state=${LOGROTATE_BASE_PATH}/var/status" "${LOGROTATE_BASE_PATH}/etc/logrotate.conf"' \
    || fail "logrotate" "call failed"

check_equals "rotated generation exists" \
    "$(docker exec "${C}" sh -c 'test -f /opt/flownative/log/nginx-error.log.1 && echo yes')" "yes"
check_equals "new log file is small" \
    "$(docker exec "${C}" sh -c 'test "$(wc -c < /opt/flownative/log/nginx-error.log)" -lt 100000 && echo yes')" "yes"

# Without PHP-FPM, the request produces an entry in the error log
sleep 1
curl -s -o /dev/null "http://localhost:${PORT}/index.php"
sleep 1
check_present "Nginx writes to the new file after postrotate" \
    "$(docker exec "${C}" sh -c "grep -c 'connect() failed' /opt/flownative/log/nginx-error.log" || echo 0)"

heading "Result"
echo "  Failed: ${FAILS}"
exit "${FAILS}"

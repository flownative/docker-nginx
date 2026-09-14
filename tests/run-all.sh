#!/usr/bin/env bash
#
# Runs all tests and summarizes the result.
#
#   CANDIDATE_IMAGE=flownative/nginx:local ./run-all.sh
#
# The individual tests can also be called directly.

set -o nounset

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=lib.sh
. ./lib.sh

TESTS=(
    "1-render.sh"
    "2-nginx-t.sh"
    "3-runtime.sh"
    "4-php-fpm.sh"
    "5-logrotate.sh"
    "6-shutdown.sh"
)

echo "Candidate : ${CANDIDATE_IMAGE}"
echo "Reference : ${REFERENCE_IMAGE}"
echo "PHP       : ${PHP_IMAGE}"

declare -a results=()
total=0

for t in "${TESTS[@]}"; do
    printf '\n\033[1m########## %s ##########\033[0m\n' "${t}"
    "./${t}"
    rc=$?
    total=$((total + rc))
    if [ "${rc}" -eq 0 ]; then
        results+=("  ok    ${t}")
    else
        results+=("  FAIL  ${t} (${rc} failed)")
    fi
done

printf '\n\033[1m########## Summary ##########\033[0m\n'
printf '%s\n' "${results[@]}"
printf '\nFailures in total: %s\n' "${total}"
exit $(( total > 0 ? 1 : 0 ))

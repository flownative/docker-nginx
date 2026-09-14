#!/usr/bin/env bash
#
# The core test: renders the Nginx configuration of both images across the
# whole environment variable matrix and compares it line by line.
#
# The contract of this image is "the documented variables keep their effect",
# and that is exactly what this checks: the rendered configuration has to be
# identical, except for the lines which were changed deliberately (see
# ACCEPTED_DIFF).

set -o nounset
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=lib.sh
. ./lib.sh

OUTDIR="${OUTDIR:-./out}"

# Lines which are allowed to differ from the reference image, written against
# the released 5.0.1.
#   fastcgi_pass  -> default of BEACH_PHP_FPM_HOST is 127.0.0.1, not localhost
#   keys_zone     -> follows NGINX_CACHE_NAME instead of being hardcoded
ACCEPTED_DIFF="${ACCEPTED_DIFF-fastcgi_pass|keys_zone}"

# ---------------------------------------------------------------------------
# render() - Renders all configurations of an image into a directory
#
render() { # image, outdir
    local image="$1" outdir="$2" name envspec
    mkdir -p "${outdir}"
    while IFS='|' read -r name envspec; do
        [ -z "${name}" ] && continue
        env_to_docker_args "${envspec}"
        # Any argument other than "run" is executed by the entrypoint after
        # initialization -- the configurations have been rendered by then.
        docker run --rm "${DOCKER_ARGS[@]}" "${image}" \
            bash -c 'for f in "${NGINX_CONF_PATH}"/nginx.conf "${NGINX_CONF_PATH}"/sites-enabled/*.conf; do
                         [ -e "$f" ] || continue
                         echo "===== $(basename "$f") ====="
                         cat "$f"
                     done' \
            >"${outdir}/${name}.conf" 2>"${outdir}/${name}.stderr"
        printf '.'
    done <<<"${MATRIX}"
    printf '\n'
}

# ---------------------------------------------------------------------------
# clean() - Removes everything from the stream which is not configuration
#
# The entrypoint logs to /dev/stdout via info(), and so does its banner; both
# end up in the same stream as the configuration. Comments are removed as well,
# so that changing a comment does not add noise to the comparison.
#
clean() {
    grep -v '^\[info\]' "$1" \
        | sed -e 's/\x1b\[[0-9;]*m//g' \
        | grep -vE '^\s*#' \
        | grep -v '^ *$' \
        | grep -vE 'Flownative|handcrafted|www\.flownative\.com|^ *NGINX *$'
}

heading "Rendering configurations: ${REFERENCE_IMAGE}"
require_image "${REFERENCE_IMAGE}" || exit 1
render "${REFERENCE_IMAGE}" "${OUTDIR}/reference"

heading "Rendering configurations: ${CANDIDATE_IMAGE}"
require_image "${CANDIDATE_IMAGE}" || exit 1
render "${CANDIDATE_IMAGE}" "${OUTDIR}/candidate"

heading "Comparison"

unexpected=0
while IFS='|' read -r name _; do
    [ -z "${name}" ] && continue
    ref="${OUTDIR}/reference/${name}.conf"
    cand="${OUTDIR}/candidate/${name}.conf"

    # Did rendering succeed at all? Check the filtered content: if the
    # entrypoint aborts, the file still holds the banner and the [info] lines,
    # but no configuration.
    if [ ! -s "${cand}" ] || [ -z "$(clean "${cand}")" ]; then
        fail "${name}" "candidate does not render: $(tail -1 "${OUTDIR}/candidate/${name}.stderr")"
        continue
    fi
    if [ ! -s "${ref}" ] || [ -z "$(clean "${ref}")" ]; then
        # The reference may be broken -- up to 5.0.1 it aborts in static mode
        # with "underScoresInHeadersDirective: unbound variable".
        pass "${name}" "only the candidate renders (reference aborts)"
        continue
    fi

    diff_out=$(diff <(clean "${ref}") <(clean "${cand}") | grep -E '^[<>]' || true)
    if [ -n "${ACCEPTED_DIFF}" ]; then
        unexpected_lines=$(grep -vE "${ACCEPTED_DIFF}" <<<"${diff_out}" | grep -E '^[<>]' || true)
    else
        unexpected_lines="${diff_out}"
    fi

    if [ -z "${diff_out}" ]; then
        pass "${name}" "identical"
    elif [ -z "${unexpected_lines}" ]; then
        pass "${name}" "$(grep -c '^[<>]' <<<"${diff_out}") expected difference(s)"
    else
        fail "${name}" "unexpected difference:"
        sed 's/^/         /' <<<"${unexpected_lines}"
        unexpected=$((unexpected + 1))
    fi
done <<<"${MATRIX}"

heading "Result"
echo "  Unexpected differences: ${unexpected}"
echo "  Raw data below: ${OUTDIR}/"
exit "${FAILS}"

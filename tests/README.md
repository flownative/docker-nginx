# Tests

CI builds this image without ever starting it. These tests close that gap: they
really start the built image and compare it against a **baseline image** rather
than against hardcoded expectations.

The contract they protect: *the environment variables documented in README.md
keep their names, defaults and effect.* Anyone touching the configuration
generation should run them before and after the change.

## Requirements

- Docker
- Bash 4+ (on macOS: `brew install bash`, the bundled 3.2 is not enough)
- Network access to Harbor and Docker Hub for the reference and PHP images

## Running

```bash
# Build the image under test (from this directory)
docker build -t flownative/nginx:local ..

# Run everything (takes a few minutes, starts a lot of containers)
./run-all.sh

# Or one at a time
./1-render.sh
```

Configuration through environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `CANDIDATE_IMAGE` | `flownative/nginx:local` | The image under test |
| `REFERENCE_IMAGE` | `harbor.flownative.io/docker/nginx:5.0.1` | The baseline it is compared against (`1-render.sh` only) |
| `PHP_IMAGE` | `flownative/beach-php:8.4` | PHP-FPM for the end-to-end test (`4-php-fpm.sh` only) |
| `ACCEPTED_DIFF` | see below | Differences `1-render.sh` tolerates; set it empty to tolerate none |

Every script exits with the number of failures as its exit code, `run-all.sh`
with 0 or 1.

## Creating a baseline from scratch

Only `1-render.sh` needs a baseline; the other scripts test the candidate on its
own. By default the baseline is a released image, pulled from Harbor — for that,
nothing needs to be done.

Build it yourself when you have no registry access, when you want to compare
against an unreleased state, or when you are about to change the configuration
generation and want to know what *your own* change does to the rendered output:

```bash
# Baseline: the state you are starting from, built before your changes
docker build -t flownative/nginx:baseline .

# ... now change the configuration generation ...

docker build -t flownative/nginx:local .
REFERENCE_IMAGE=flownative/nginx:baseline ACCEPTED_DIFF= ./1-render.sh
```

`ACCEPTED_DIFF=` is what makes this strict: the list is written against a 
released version, and a baseline built from this branch already contains those
fixes. Leaving the list in place would hide changes to exactly those lines.
Every line of the rendered configuration which differs is then a failure, and
the ones you changed on purpose are listed in the output for review.

To build the baseline from a released state instead of from the working tree,
check that state out into a worktree, so your own is left alone:

```bash
git worktree add /tmp/nginx-baseline v5.0.1
docker build -t flownative/nginx:baseline /tmp/nginx-baseline
git worktree remove /tmp/nginx-baseline
```

## The tests

| Script | What it checks |
|---|---|
| `1-render.sh` | **The core test.** Renders the configuration of both images across the whole variable matrix and compares it line by line. Everything except the deliberately changed lines has to be identical. |
| `2-nginx-t.sh` | `nginx -t` across the same matrix. Catches syntax errors and a `headers_more` module which cannot be loaded. |
| `3-runtime.sh` | Real requests: serving files, status endpoint, `more_set_headers`, logging to file *and* stream. |
| `4-php-fpm.sh` | End-to-end against the real `beach-php` image, including the startup race. |
| `5-logrotate.sh` | That the logrotate configuration rotates the log files and Nginx writes to the new file afterwards. |
| `6-shutdown.sh` | That `docker stop` arrives and Nginx serves a running download to the end. |

`lib.sh` holds the variable matrix and the shared helpers. Anyone introducing a
new environment variable adds it there — `1-render.sh` and `2-nginx-t.sh` then
cover it automatically.

## Expected differences in `1-render.sh`

These lines may differ from the reference image, nothing else (the list lives
in the script as `ACCEPTED_DIFF`):

- `fastcgi_pass` — the default of `BEACH_PHP_FPM_HOST` is `127.0.0.1` instead of `localhost`
- `keys_zone` — follows `NGINX_CACHE_NAME` now, instead of being hardcoded

**This list is written against 5.0.1.** Once a version containing these fixes is
released, `REFERENCE_IMAGE` points at exactly that one — the differences are
gone then, and `ACCEPTED_DIFF` should be emptied in the script. From then on
*every* difference is a failure until somebody deliberately enters it here. If
the list stays as it is, the test no longer covers those lines at all.

## When tests fail

`1-render.sh` writes the rendered configurations to `out/reference/` and
`out/candidate/`. Compare them directly:

```bash
diff out/reference/cache.conf out/candidate/cache.conf
```

## Pitfalls

While these tests were written, several failures turned out to be bugs *in the
test*, not in the image. Whoever works on them next saves time by knowing:

- **`maxsize 50M` means 52,428,800 bytes.** A file of 52,000,000 bytes does not
  trigger the rotation, and logrotate does not report that as an error.
- **logrotate only runs every fifth minute.** `logrotate-cron.sh` from the base
  image checks `date +%M`. `5-logrotate.sh` therefore does not wait for it, but
  performs the same call itself.
- **The stream log comes from syslog-ng.** Nginx writes to the files only,
  syslog-ng mirrors them to stdout. The JSON access log shows up there only with
  `SYSLOG_JSON=true`, the text log only without it — a missing JSON log in the
  stream is not a bug as long as that variable is unset.
- **Do not request too early.** syslog-ng and supervisord need a few seconds
  before Nginx listens. Fixed `sleep`s were too tight, hence `wait_for_http` and
  `wait_for_port` (which accepts a 502 as well).
- **The shutdown download has to run long enough.** It takes about two seconds
  until SIGQUIT reaches Nginx (`sleep 1.1` in the entrypoint, plus starting
  supervisorctl). A shorter download is finished before that, and the test
  passes even on a "fast shutdown".
- **Access log lines show up more than once.** The error log contains the
  request line as well, and Nginx retries failed upstreams. That is why
  `check_present` checks for "at least once", not for "exactly once".
- **`NGINX_ACCESS_LOG_ENABLE` only has an effect in Flow mode.** In static mode
  the code does not emit an `access_log` directive at all. Testing logging there
  would test something that never existed.
- **The entrypoint logs to `/dev/stdout`.** When rendering the configuration,
  `[info]` lines and the banner end up in the same stream — `clean()` in
  `1-render.sh` filters them out.
- **A fake FastCGI listener is useless.** Nginx then waits for
  `fastcgi_read_timeout` (240s). The end-to-end test needs real PHP-FPM.
- **The reference is broken in static mode.** Up to `5.0.1` it aborts with
  `underScoresInHeadersDirective: unbound variable`; `1-render.sh` reports that
  as "only the candidate renders" instead of as a failure. That check has to
  look at the *filtered* content — despite the crash the output file is not
  empty, because the banner and the `[info]` lines are in it.

## Counter-check

Green tests prove little unless it is clear that they can fail. Against 5.0.1
they find the bugs which have been fixed since:

```bash
CANDIDATE_IMAGE=harbor.flownative.io/docker/nginx:5.0.1 ./2-nginx-t.sh    # 4 failures
CANDIDATE_IMAGE=harbor.flownative.io/docker/nginx:5.0.1 ./4-php-fpm.sh    # "no live upstreams"
CANDIDATE_IMAGE=harbor.flownative.io/docker/nginx:5.0.1 ./5-logrotate.sh  # no rotation
CANDIDATE_IMAGE=harbor.flownative.io/docker/nginx:5.0.1 ./6-shutdown.sh   # killed after 30s
```

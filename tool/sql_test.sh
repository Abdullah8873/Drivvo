#!/usr/bin/env bash
# Runs every file in supabase/migrations/ on a throwaway LOCAL Postgres,
# then the checks in supabase/local-test/ (RLS, guards, quotas, Storage
# policies, transfer rate limits) as simulated Supabase users.
#
#   bash tool/sql_test.sh            # all migrations + checks
#   bash tool/sql_test.sh --keep     # leave the server running afterwards
#
# Needs a local PostgreSQL (15+) server install: `initdb`/`pg_ctl` on PATH
# or under /usr/lib/postgresql/<n>/bin (Ubuntu: apt-get install postgresql).
# It never talks to Supabase: supabase/local-test/00_supabase_stub.sql
# stands in for the auth/storage schemas. A pass here doesn't replace the
# begin … rollback dry run on the real project (Supabase's Storage API and
# auth internals are only approximated).
set -euo pipefail
cd "$(dirname "$0")/.."

keep=false
[ "${1:-}" = "--keep" ] && keep=true

bin=""
if command -v initdb >/dev/null 2>&1; then
  bin="$(dirname "$(command -v initdb)")"
else
  bin="$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -n 1)"
fi
if [ -z "$bin" ] || [ ! -x "$bin/initdb" ]; then
  echo "PostgreSQL server binaries not found (initdb). Install postgresql." >&2
  exit 2
fi

work="$(mktemp -d)"
port=55439
chmod 755 "$work"
# Postgres refuses to run as root: use the postgres OS user when we are root.
run() {
  if [ "$(id -u)" = 0 ]; then su postgres -s /bin/bash -c "$*"; else bash -c "$*"; fi
}
[ "$(id -u)" = 0 ] && chown postgres "$work"

cleanup() {
  if ! $keep; then
    run "'$bin/pg_ctl' -D '$work/data' -m immediate stop" >/dev/null 2>&1 || true
    rm -rf "$work"
  fi
}
trap cleanup EXIT

run "'$bin/initdb' -D '$work/data' -A trust -U postgres" >/dev/null
run "'$bin/pg_ctl' -D '$work/data' -o \"-k '$work' -p $port -c listen_addresses=''\" -l '$work/log' -w start" >/dev/null

psql_() {
  PGOPTIONS='-c client_min_messages=warning' \
    "$bin/psql" -h "$work" -p "$port" -U postgres -X -q -v ON_ERROR_STOP=1 -o /dev/null "$@"
}

psql_ -c 'create database motolog_test'
psql_ -d motolog_test -f supabase/local-test/00_supabase_stub.sql
for f in supabase/migrations/*.sql; do
  echo "migrate: $f"
  psql_ -d motolog_test -f "$f"
done
# Idempotency: the newest migration must survive a second run.
latest="$(ls supabase/migrations/*.sql | sort | tail -n 1)"
echo "re-run:  $latest"
psql_ -d motolog_test -f "$latest"

for f in supabase/local-test/[1-9]*.sql; do
  echo "check:   $f"
  if ! PGOPTIONS='-c client_min_messages=notice' \
    "$bin/psql" -h "$work" -p "$port" -U postgres -X -q -v ON_ERROR_STOP=1 \
    -d motolog_test -f "$f" -o /dev/null 2>&1 | sed -e 's/^psql:[^ ]* NOTICE:  /  /'; then
    echo "FAILED: $f" >&2
    exit 1
  fi
done
echo "All SQL checks passed."
if $keep; then
  echo "Server left running: psql -h $work -p $port -U postgres motolog_test"
fi

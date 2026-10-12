#!/bin/bash
# ===============================================
# Suite - Service Container entrypoint
# Starts the service's own PostgreSQL, then the command (sshd)
# ===============================================
set -euo pipefail

: "${DB_NAME:?DB_NAME is required}"
: "${DB_USER:?DB_USER is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"
DB_PORT="${DB_PORT:-5432}"

PG_BIN="/usr/lib/postgresql/${PG_MAJOR}/bin"

as_postgres() { runuser -u postgres -- "$@"; }

# -----------------------------------------------
# Make the container environment visible to SSH sessions
# (sshd does not pass it on; pam_env reads /etc/environment)
# -----------------------------------------------
touch /etc/environment
for var in SERVICE_NAME API_PORT SOCKET_PORT \
           DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD \
           EVENT_BUS_HOST EVENT_BUS_PORT EVENT_BUS_PASSWORD; do
    sed -i "/^${var}=/d" /etc/environment
    if [ -n "${!var:-}" ]; then
        printf '%s="%s"\n' "$var" "${!var}" >> /etc/environment
    fi
done

# -----------------------------------------------
# PostgreSQL: create the cluster on first start
# -----------------------------------------------
install -d -o postgres -g postgres -m 700 "$PGDATA"
chown -R postgres:postgres "$PGDATA"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
    as_postgres "$PG_BIN/initdb" -D "$PGDATA" -E UTF8 --locale=C.UTF-8 \
        --auth-local=peer --auth-host=scram-sha-256
fi

# Nothing else can be running at container start: a leftover pid file is stale
rm -f "$PGDATA/postmaster.pid"

# The database belongs to this service only: it never listens outside the container
as_postgres "$PG_BIN/pg_ctl" -D "$PGDATA" -w start \
    -o "-c listen_addresses=127.0.0.1 -c port=${DB_PORT}"

# Role and database (idempotent)
as_postgres psql -v ON_ERROR_STOP=1 -p "$DB_PORT" -d postgres \
    -v db_user="$DB_USER" -v db_password="$DB_PASSWORD" -v db_name="$DB_NAME" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'db_user', :'db_password')
 WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'db_user') \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_user')
 WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db_name') \gexec
SQL

# -----------------------------------------------
# Run the command, stop PostgreSQL cleanly on shutdown
# -----------------------------------------------
shutdown() {
    kill "$cmd_pid" 2>/dev/null || true
    as_postgres "$PG_BIN/pg_ctl" -D "$PGDATA" -m fast -w stop || true
    exit 0
}
trap shutdown TERM INT

"$@" &
cmd_pid=$!
wait "$cmd_pid" || true
shutdown

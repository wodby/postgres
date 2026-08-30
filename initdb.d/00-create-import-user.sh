#!/usr/bin/env bash

set -e

if [[ -z "${POSTGRES_INITDB_USER:-}" && -z "${POSTGRES_INITDB_PASSWORD:-}" ]]; then
    exit 0
fi

if [[ -z "${POSTGRES_INITDB_USER:-}" || -z "${POSTGRES_INITDB_PASSWORD:-}" ]]; then
    echo "POSTGRES_INITDB_USER and POSTGRES_INITDB_PASSWORD must be specified together" >&2
    exit 1
fi

# Avoid exposing the managed password in DEBUG output while passing it to psql.
restore_xtrace=0
if [[ -o xtrace ]]; then
    restore_xtrace=1
    set +x
fi

psql \
    --username "${POSTGRES_USER}" \
    --dbname "${POSTGRES_DB}" \
    --set ON_ERROR_STOP=1 \
    --set managed_user="${POSTGRES_INITDB_USER}" \
    --set managed_password="${POSTGRES_INITDB_PASSWORD}" <<-'EOSQL'
	SELECT format(
	    'CREATE ROLE %I LOGIN PASSWORD %L',
	    :'managed_user',
	    :'managed_password'
	)
	WHERE NOT EXISTS (
	    SELECT 1
	    FROM pg_catalog.pg_roles
	    WHERE rolname = :'managed_user'
	)
	\gexec
EOSQL

if [[ "${restore_xtrace}" == "1" ]]; then
    set -x
fi

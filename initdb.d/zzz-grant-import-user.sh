#!/usr/bin/env bash

set -e

if [[ -n "${DEBUG}" ]]; then
    set -x
fi

if [[ -z "${POSTGRES_INITDB_USER:-}" ]]; then
    exit 0
fi

# The maintenance database is shared by every role, so the managed user keeps plain access to it.
if ! db-layout manageable "${POSTGRES_DB}"; then
    exit 0
fi

# Runs after the import: the imported objects were created by the administrator and are handed to
# the owner role here, which is what gives the managed user access to them.
#
# A dump taken by an earlier release keeps its objects in a schema named after the database it was
# taken from. POSTGRES_INITDB_SOURCE_DB names that database when it differs from this one.
POSTGRES_LAYOUT_LEGACY_SCHEMAS="${POSTGRES_INITDB_SOURCE_DB:-}" \
    db-layout grant "${POSTGRES_DB}" "${POSTGRES_INITDB_USER}"
db-layout lock-down "${POSTGRES_DB}"

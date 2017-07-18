#!/usr/bin/env bash

set -e

if [[ -n "${DEBUG}" ]]; then
    set -x
fi

echo -n "Creation extensions... "

for extension in $(awk -F',' '{for (i = 1 ; i <= NF ; i++) print $i}' <<< "${POSTGRES_DB_EXTENSIONS}"); do
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "CREATE EXTENSION IF NOT EXISTS ${extension};" >/dev/null 2>&1
done

echo "OK"
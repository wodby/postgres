#!/usr/bin/env bash

set -e

if [[ ! -z "${DEBUG}" ]]; then
  set -x
fi

started=0
user=$1
password=$2
db=$3
host=$4
max_try=$5
wait_seconds=$6

for i in $(seq 1 "${max_try}"); do
    if PGPASSWORD="${password}" psql -U"${user}" -h"${host}" -d"${db}" -c 'SELECT 1' &> /dev/null; then
        started=1
        break
    fi
    echo 'PostgreSQL is starting...'
    sleep "${wait_seconds}"
done

if [[ "${started}" -eq '0' ]]; then
    echo >&2 'Error. PostgreSQL is unreachable.'
    exit 1
fi

echo 'PostgreSQL has started!'

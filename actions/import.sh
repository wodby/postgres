#!/usr/bin/env bash

set -e

if [[ -n "${DEBUG}" ]]; then
    set -x
fi

user=$1
password=$2
host=$3
db=$4
source=$5
binary=$6
tmp_dir="/tmp/import"

get-archive.sh "${source}" "${tmp_dir}" "zip tgz tar.gz gz"

dump_file=$(find "${tmp_dir}" -type f)
count=$(echo "${dump_file}" | wc -l | grep -Eo '[0-9]+')

if [[ "${count}" == 1 ]]; then
    PGPASSWORD="${password}" dropdb -U"${user}" -h"${host}" "${db}"
    PGPASSWORD="${password}" createdb -U"${user}" -h"${host}" "${db}"

    if [[ "${binary}" == 1 ]]; then
        PGPASSWORD="${password}" pg_restore -U"${user}" -h"${host}" -d"${db}" "${dump_file}"
    else
        PGPASSWORD="${password}" psql -U"${user}" -h"${host}" -d"${db}" -f "${dump_file}"
    fi

    rm -rf "${tmp_dir}"
else
    rm -rf "${tmp_dir}"
    echo >&2 "Expecting single archived file, none or multiple found: ${dump_file}"
    exit 1
fi
#!/usr/bin/env bash

set -e

if [[ ! -z "${DEBUG}" ]]; then
  set -x
fi

user=$1
password=$2
host=$3
db=$4
filepath=$5
exclude_tables=$6
filename="dump.sql"
tmp_dir="/tmp/$RANDOM"
ignore=()

IFS=';' read -ra ADDR <<< "${exclude_tables}"
for table in "${ADDR[@]}"; do
    ignore+=("--exclude-table-data=${table}")
done

mkdir -p "${tmp_dir}"
cd "${tmp_dir}"
PGPASSWORD="${password}" pg_dump "${ignore[@]}" -U"${user}" -h"${host}" "${db}" > "${filename}"
gzip "${filename}"
mv "${filename}.gz" "${filepath}"
stat -c "RESULT=%s" "${filepath}"
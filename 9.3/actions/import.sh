#!/usr/bin/env bash

set -e

if [[ ! -z "${DEBUG}" ]]; then
  set -x
fi

user=$1
password=$2
host=$3
db=$4
source=$5
binary=$6
tmp_dir="/tmp/import"

[ -d "${tmp_dir}" ] && rm -rf "${tmp_dir}"
mkdir -p "${tmp_dir}"
cd "${tmp_dir}"

if [[ "${source}" =~ ^https?:// ]]; then
    wget -q "${source}"
else
    mv "${source}" .
fi

archive_file=$(find -type f)

if [[ "${archive_file}" =~ \.zip$ ]]; then
    unzip "${archive_file}"
    rm -f "${archive_file}"
elif [[ "${archive_file}" =~ \.tgz$ ]] || [[ "${archive_file}" =~ \.tar.gz$ ]]; then
    tar -zxf "${archive_file}"
    rm -f "${archive_file}"
elif [[ "${archive_file}" =~ \.gz$ ]]; then
    gunzip "${archive_file}"
else
    echo >&2 'Unsupported file format. Expecting single file compressed as .gz .zip .tar.gz .tgz'
    exit 1
fi

if [ "$(find -type f | wc -l)" != "1" ]; then
    echo >&2 "Expecting single .sql file, none or multiple found: $(find -type f)"
    exit 1
fi

dump_file=$(find -type f)

PGPASSWORD="${password}" dropdb -U"${user}" -h"${host}" "${db}"
PGPASSWORD="${password}" createdb -U"${user}" -h"${host}" "${db}"

if [[ "${binary}" == 1 ]]; then
    PGPASSWORD="${password}" pg_restore -U"${user}" -h"${host}" -d"${db}" "${dump_file}"
else
    PGPASSWORD="${password}" psql -U"${user}" -h"${host}" -d"${db}" -f "${dump_file}"
fi


rm -rf "${tmp_dir}"
#!/usr/bin/env bash

set -e

if [[ -n "${DEBUG}" ]]; then
    set -x
fi

postgres_ver=$1
postgres_major_ver=$2

url="https://raw.githubusercontent.com/postgres/postgres/REL_${postgres_ver//./_}/src/backend/utils/misc/postgresql.conf.sample"

outdated=0

md5_local=$(cat "./orig/postgresql-${postgres_major_ver}.conf.sample" | md5sum)
md5_remote=$(wget -qO- "${url}" | md5sum)

echo "Checking ${local}"

if [[ "${md5_local}" != "${md5_remote}" ]]; then
    echo "!!! OUTDATED"
    echo "SEE ${url}"
    outdated=1
else
    echo "OK"
fi

[[ "${outdated}" == 0 ]] || exit 1
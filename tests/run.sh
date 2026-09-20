#!/bin/bash

set -e

if [[ -n "${DEBUG}" ]]; then
    set -x
fi

export POSTGRES_PASSWORD='password'
export POSTGRES_USER='superuser'
export POSTGRES_DB='postgres'
export POSTGRES_INITDB_USER='managed_user'
export POSTGRES_INITDB_PASSWORD='managed-password'

import_dir="$(mktemp -d)"
managed_import_dir="$(mktemp -d)"
chmod 755 "${import_dir}" "${managed_import_dir}"
cid=''
managed_cid=''
cleanup() {
	if [[ -n "${cid}" ]]; then
		docker rm -vf "${cid}" >/dev/null
	fi
	if [[ -n "${managed_cid}" ]]; then
		docker rm -vf "${managed_cid}" >/dev/null
	fi
	rm -r "${import_dir}" "${managed_import_dir}"
}
trap cleanup EXIT

cat > "${import_dir}/import.sql" <<'SQL'
CREATE TABLE managed_import_test (value text NOT NULL);
ALTER TABLE managed_import_test OWNER TO managed_user;
INSERT INTO managed_import_test VALUES ('imported');
SQL

image_default_extensions="$(
	docker run --rm --entrypoint sh "${IMAGE}" -c 'printf %s "${POSTGRES_DB_EXTENSIONS}"'
)"
if tr ',' '\n' <<< "${image_default_extensions}" | grep -qx vector; then
	echo "pgvector must be bundled but disabled by default" >&2
	exit 1
fi

required_extensions=(pg_trgm)
if [[ "${TEST_POSTGIS}" == "1" ]]; then
	required_extensions+=(
		postgis
		postgis_raster
		postgis_sfcgal
		fuzzystrmatch
		address_standardizer
		address_standardizer_data_us
		postgis_tiger_geocoder
		postgis_topology
	)
fi
if [[ "${TEST_PGVECTOR}" == "1" ]]; then
	required_extensions+=(pg_stat_statements pgcrypto vector)
	export POSTGRES_SHARED_PRELOAD_LIBRARIES='pg_stat_statements'
fi
db_extensions="$(IFS=,; echo "${required_extensions[*]}")"
export POSTGRES_DB_EXTENSIONS="${db_extensions}"

cid="$(
	docker run -d \
		-e POSTGRES_PASSWORD \
		-e POSTGRES_USER \
		-e POSTGRES_DB \
		-e POSTGRES_INITDB_USER \
		-e POSTGRES_INITDB_PASSWORD \
		-e POSTGRES_DB_EXTENSIONS \
		-e POSTGRES_SHARED_PRELOAD_LIBRARIES \
		-e DEBUG \
		-v "${import_dir}:/wodby/import:ro" \
		--name "${NAME}" \
		"${IMAGE}"
)"

postgres() {
	docker run --rm -i \
	    -e POSTGRES_USER -e POSTGRES_PASSWORD -e POSTGRES_DB -e POSTGRES_DB_EXTENSIONS -e DEBUG \
	    -v /tmp:/mnt \
	    --link "${NAME}":"postgres" \
	    "${IMAGE}" \
	    "$@" \
	    host="postgres"
}

# Runs SQL from stdin against a server, so function bodies and quotes need no escaping.
sql() {
	local server="$1" user="$2" password="$3" db="$4"
	docker run --rm -i \
	    -e POSTGRES_PASSWORD -e PGPASSWORD="${password}" \
	    --link "${server}":"postgres" \
	    "${IMAGE}" \
	    psql -X -q -tA -v ON_ERROR_STOP=1 -h postgres -U "${user}" -d "${db}" -f -
}

admin_sql() {
	sql "${NAME}" "${POSTGRES_USER}" "${POSTGRES_PASSWORD}" "$1"
}

postgres make check-ready max_try=12 wait_seconds=5

echo -n "Checking initialization import user... "
[ "$(postgres make query-silent user="${POSTGRES_INITDB_USER}" password="${POSTGRES_INITDB_PASSWORD}" query='SELECT value FROM managed_import_test')" = 'imported' ]
[ "$(postgres make query-silent query="SELECT tableowner FROM pg_catalog.pg_tables WHERE tablename = 'managed_import_test'")" = "${POSTGRES_INITDB_USER}" ]
echo "OK"

echo -n "Checking extensions... "
installed_extensions="$(postgres make query-silent query='SELECT extname FROM pg_extension ORDER BY 1')"
for extension in "${required_extensions[@]}"; do
	grep -qx "${extension}" <<< "${installed_extensions}"
done
echo "OK"

if [[ "${TEST_POSTGIS}" == "1" ]]; then
	echo -n "Running extension smoke tests... "
	similarity_query="SELECT similarity('postgres', 'postgis') > 0"
	levenshtein_query="SELECT levenshtein('kitten'::text, 'sitting'::text)"
	topology_query="SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'topology' AND table_name = 'topology')"
	[ "$(postgres make query-silent query="${similarity_query}")" = 't' ]
	[ "$(postgres make query-silent query="${levenshtein_query}")" = '3' ]
	postgres make query-silent query='SELECT postgis_version()' >/dev/null
	postgres make query-silent query='SELECT postgis_raster_lib_version()' >/dev/null
	postgres make query-silent query='SELECT postgis_sfcgal_version()' >/dev/null
	[ "$(postgres make query-silent query="${topology_query}")" = 't' ]
	[ "$(postgres make query-silent query='SELECT COUNT(*) > 0 FROM tiger.pagc_rules')" = 't' ]
	[ "$(postgres make query-silent query='SELECT COUNT(*) > 0 FROM public.us_lex')" = 't' ]
	echo "OK"
fi

echo -n "Create DB... "
postgres make create-db name='superdatabase' encoding='UTF8' lc_collate='en_US.utf8' lc_ctype='en_US.utf8'
postgres make create-db name='superdatabase'
[ "$(admin_sql postgres <<< "SELECT r.rolname FROM pg_database d JOIN pg_roles r ON r.oid = d.datdba WHERE d.datname = 'superdatabase'")" = 'superdatabase:owner' ]
[ "$(admin_sql postgres <<< "SELECT rolcanlogin FROM pg_roles WHERE rolname = 'superdatabase:owner'")" = 'f' ]
[ "$(admin_sql superdatabase <<< "SELECT count(*) FROM pg_namespace WHERE nspname = 'superdatabase'")" = '0' ]
created_db_extensions="$(postgres make query-silent db='superdatabase' query='SELECT extname FROM pg_extension ORDER BY 1')"
for extension in "${required_extensions[@]}"; do
	grep -qx "${extension}" <<< "${created_db_extensions}"
done
echo "OK"

echo -n "Create user... "
postgres make create-user username='userpg123' password='bad-password'
postgres make create-user username='userpg123' password='bad-password'
if postgres make create-user username='userpg123' password='unexpected-password'; then
	echo "Create user unexpectedly replaced credentials" >&2
	exit 1
fi
[ "$(postgres make query-silent user='userpg123' password='bad-password' query='SELECT 1')" = '1' ]
echo "OK"

echo -n "Grant user... "
postgres make grant-user-db username='userpg123' db='superdatabase'
postgres make grant-user-db username='userpg123' db='superdatabase'
[ "$(sql "${NAME}" userpg123 bad-password superdatabase <<< 'SELECT current_user, session_user')" = 'superdatabase:owner|userpg123' ]
sql "${NAME}" userpg123 bad-password superdatabase <<< "CREATE TABLE items (id serial PRIMARY KEY, name text); INSERT INTO items (name) VALUES ('first')"
[ "$(admin_sql superdatabase <<< "SELECT schemaname, tableowner FROM pg_tables WHERE tablename = 'items'")" = 'public|superdatabase:owner' ]
# A client that pins the schema, as several ORMs do by default.
[ "$(docker run --rm -e POSTGRES_PASSWORD -e PGPASSWORD=bad-password -e PGOPTIONS='-c search_path=public' --link "${NAME}":postgres "${IMAGE}" psql -X -tA -h postgres -U userpg123 -d superdatabase -c 'SELECT count(*) FROM items')" = '1' ]
if [[ "${TEST_PGVECTOR}" == "1" ]]; then
	[ "$(postgres make query-silent query='SELECT COUNT(*) >= 0 FROM pg_stat_statements')" = 't' ]
	postgres make query-silent user='userpg123' password='bad-password' db='superdatabase' query='CREATE TABLE vector_items (embedding vector(3))' >/dev/null
	postgres make query-silent user='userpg123' password='bad-password' db='superdatabase' query="INSERT INTO vector_items VALUES ('[1,2,3]'), ('[4,5,6]')" >/dev/null
	[ "$(postgres make query-silent user='userpg123' password='bad-password' db='superdatabase' query="SELECT embedding::text FROM vector_items ORDER BY embedding <-> '[3,1,2]' LIMIT 1")" = '[1,2,3]' ]
fi
echo "OK"

echo -n "Second user shares the data... "
postgres make create-user username='seconduser' password='second-password'
postgres make grant-user-db username='seconduser' db='superdatabase'
[ "$(sql "${NAME}" seconduser second-password superdatabase <<< "INSERT INTO items (name) VALUES ('second'); SELECT count(*) FROM items")" = '2' ]
sql "${NAME}" seconduser second-password superdatabase <<< 'CREATE TABLE notes (body text)'
[ "$(sql "${NAME}" userpg123 bad-password superdatabase <<< 'SELECT count(*) FROM notes')" = '0' ]
echo "OK"

echo -n "Revoke user... "
postgres make revoke-user-db username='seconduser' db='superdatabase'
if sql "${NAME}" seconduser second-password superdatabase <<< 'SELECT 1' 2>/dev/null; then
	echo "Revoked user can still connect" >&2
	exit 1
fi
[ "$(admin_sql postgres <<< "SELECT pg_has_role('seconduser', 'superdatabase:owner', 'MEMBER')")" = 'f' ]
# The revoked user owns nothing, so it can be dropped right away.
postgres make drop-user username='seconduser'
[ "$(sql "${NAME}" userpg123 bad-password superdatabase <<< 'SELECT count(*) FROM notes')" = '0' ]
echo "OK"

echo -n "Convert a database of earlier releases... "
# What create-db and grant-user-db of 1.40 to 1.47 set up: a schema named after the database.
admin_sql postgres <<'SQL'
CREATE DATABASE legacydb;
CREATE USER legacyuser PASSWORD 'legacy-password';
CREATE USER legacyreader PASSWORD 'reader-password';
SQL
admin_sql legacydb <<'SQL'
CREATE SCHEMA "legacydb";
GRANT ALL PRIVILEGES ON DATABASE "legacydb" TO "legacyuser";
GRANT ALL PRIVILEGES ON SCHEMA "legacydb" TO "legacyuser";
ALTER ROLE "legacyuser" IN DATABASE "legacydb" SET search_path TO "legacydb", public;
GRANT ALL PRIVILEGES ON DATABASE "legacydb" TO "legacyreader";
GRANT ALL PRIVILEGES ON SCHEMA "legacydb" TO "legacyreader";
ALTER ROLE "legacyreader" IN DATABASE "legacydb" SET search_path TO "legacydb", public;
SQL
sql "${NAME}" legacyuser legacy-password legacydb <<'SQL'
CREATE EXTENSION pg_trgm;
CREATE TYPE status AS ENUM ('new', 'done');
CREATE TYPE span AS RANGE (subtype = numeric);
CREATE TABLE tasks (id serial PRIMARY KEY, seq int GENERATED ALWAYS AS IDENTITY, title text, state status DEFAULT 'new', width span);
CREATE TABLE log (at date NOT NULL, line text) PARTITION BY RANGE (at);
CREATE TABLE log_2026 PARTITION OF log FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE SEQUENCE ticket START 100;
CREATE FUNCTION task_count() RETURNS bigint LANGUAGE plpgsql AS $$ BEGIN RETURN (SELECT count(*) FROM tasks); END $$;
CREATE VIEW open_tasks AS SELECT * FROM tasks WHERE state = 'new';
INSERT INTO tasks (title, width) VALUES ('one', '[1,2)'), ('two', '[2,3)');
SQL
sql "${NAME}" legacyreader reader-password legacydb <<< "CREATE TABLE reader_notes (body text); INSERT INTO reader_notes VALUES ('mine')"
if sql "${NAME}" legacyreader reader-password legacydb <<< 'SELECT count(*) FROM tasks' 2>/dev/null; then
	echo "Users of the earlier layout unexpectedly shared their tables" >&2
	exit 1
fi
postgres make grant-user-db username='legacyuser' db='legacydb'
[ "$(admin_sql legacydb <<< "SELECT count(*) FROM pg_namespace WHERE nspname = 'legacydb'")" = '0' ]
[ "$(admin_sql legacydb <<< "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace JOIN pg_roles r ON r.oid = c.relowner WHERE c.relname IN ('tasks', 'log', 'log_2026', 'ticket', 'open_tasks', 'reader_notes', 'tasks_id_seq') AND n.nspname = 'public' AND r.rolname = 'legacydb:owner'")" = '7' ]
[ "$(admin_sql legacydb <<< "SELECT n.nspname FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace WHERE e.extname = 'pg_trgm'")" = 'public' ]
[ "$(admin_sql postgres <<< "SELECT count(*) FROM pg_db_role_setting s JOIN pg_database d ON d.oid = s.setdatabase WHERE d.datname = 'legacydb' AND 'search_path=legacydb, public' = ANY (s.setconfig)")" = '0' ]
[ "$(sql "${NAME}" legacyuser legacy-password legacydb <<< "INSERT INTO tasks (title) VALUES ('three'); SELECT task_count(), (SELECT count(*) FROM open_tasks), nextval('ticket'), (SELECT width @> 1.5 FROM tasks WHERE id = 1)")" = '3|3|100|t' ]
[ "$(sql "${NAME}" legacyreader reader-password legacydb <<< 'SELECT (SELECT count(*) FROM tasks), (SELECT count(*) FROM reader_notes)')" = '3|1' ]
# Converting again finds nothing to do.
[ "$(postgres make grant-user-db username='legacyreader' db='legacydb' | grep -c -E 'Moving|Transferring')" = '0' ]
postgres make drop-db name='legacydb'
postgres make drop-user username='legacyuser'
postgres make drop-user username='legacyreader'
echo "OK"

echo -n "Drop DB... "
postgres make drop-db name='superdatabase' encoding='UTF8' lc_collate='en_US.utf8' lc_ctype='en_US.utf8'
dropped_db_query="SELECT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'superdatabase')"
[ "$(postgres make query-silent query="${dropped_db_query}")" = 'f' ]
[ "$(admin_sql postgres <<< "SELECT count(*) FROM pg_roles WHERE rolname = 'superdatabase:owner'")" = '0' ]
echo "OK"

echo -n "Drop user... "
postgres make drop-user username='userpg123' password='bad-password'
echo "OK"

echo -n "Running queries... "
postgres make query query="CREATE TABLE test (a INT, b INT, c VARCHAR(255))"
[ "$(postgres make query-silent query='SELECT COUNT(*) FROM test')" = 0 ]
postgres make query query="INSERT INTO test VALUES (1, 2, 'hello')"
[ "$(postgres make query-silent query='SELECT COUNT(*) FROM test')" = 1 ]
postgres make query query="INSERT INTO test VALUES (2, 3, 'goodbye!')"
[ "$(postgres make query-silent query='SELECT COUNT(*) FROM test')" = 2 ]
postgres make query query="DELETE FROM test WHERE a = 1"
[ "$(postgres make query-silent query='SELECT COUNT(*) FROM test')" = 1 ]
postgres make query query="DELETE FROM test WHERE a = 1"
[ "$(postgres make query-silent query='SELECT c FROM test')" = 'goodbye!' ]
postgres make query query="DELETE FROM test WHERE a = 1"

postgres make query query="CREATE TABLE test1 (a INT, b INT, c VARCHAR(255))"
postgres make query query="CREATE TABLE test2 (a INT, b INT, c VARCHAR(255))"
postgres make query query="INSERT INTO test1 VALUES (1, 2, 'hello')"
postgres make query query="INSERT INTO test2 VALUES (1, 2, 'hello!')"
echo "OK"

echo -n "Running backups... "
postgres make backup filepath="/mnt/export.sql.gz" ignore="test1;test2"
echo "OK"

echo -n "Checking the backup names no role... "
if postgres bash -c 'gunzip -c /mnt/export.sql.gz | grep -E "OWNER TO|^GRANT |^REVOKE "'; then
	echo "Backup is tied to the roles of this server" >&2
	exit 1
fi
echo "OK"

echo -n "Running import from file... "
postgres make import source="/mnt/export.sql.gz"
echo "OK"

echo -n "Running import into a managed database... "
postgres make create-db name='portable'
postgres make create-user username='portableuser' password='portable-password'
postgres make grant-user-db username='portableuser' db='portable'
# An import consumes its source file, so this one gets a backup of its own.
postgres make backup filepath="/mnt/portable.sql.gz" ignore="test1;test2"
postgres make import source="/mnt/portable.sql.gz" db='portable'
[ "$(admin_sql postgres <<< "SELECT r.rolname FROM pg_database d JOIN pg_roles r ON r.oid = d.datdba WHERE d.datname = 'portable'")" = 'portable:owner' ]
[ "$(sql "${NAME}" portableuser portable-password portable <<< 'SELECT current_user, (SELECT count(*) FROM test)')" = 'portable:owner|1' ]
[ "$(admin_sql portable <<< "SELECT tableowner FROM pg_tables WHERE tablename = 'test'")" = 'portable:owner' ]
postgres make drop-db name='portable'
postgres make drop-user username='portableuser'
echo "OK"

echo -n "Checking ignored tables from backup/import... "
[ "$(postgres make query-silent query='SELECT COUNT(*) FROM test')" = 1 ]
[ "$(postgres make query-silent query='SELECT COUNT(*) FROM test1')" = 0 ]
[ "$(postgres make query-silent query='SELECT COUNT(*) FROM test2')" = 0 ]
echo "OK"

echo -n "Running streaming backup and restore... "
stream_dir="$(mktemp -d)"
chmod 777 "${stream_dir}"
docker run --rm \
    -e POSTGRES_USER -e POSTGRES_PASSWORD -e POSTGRES_DB \
    -v "${stream_dir}:/stream" \
    --link "${NAME}":postgres \
    "${IMAGE}" bash -ceu '
        mkfifo /stream/data
        touch /stream/status
        chmod 666 /stream/data /stream/status
        cat /stream/data > /stream/export.sql.gz &
        reader=$!
        make -f /usr/local/bin/actions.mk backup-stream \
            host=postgres \
            ignore="test1;test2" \
            stream_path=/stream/data \
            status_path=/stream/status
        wait "${reader}"
        test "$(cat /stream/status)" = 0

        rm /stream/data /stream/status
        mkfifo /stream/data
        touch /stream/status
        chmod 666 /stream/data /stream/status
        cat /stream/data >/dev/null &
        reader=$!
        if make -f /usr/local/bin/actions.mk backup-stream \
            host=postgres \
            db=missing_stream_backup_database \
            stream_path=/stream/data \
            status_path=/stream/status; then
            exit 1
        fi
        wait "${reader}"
        test "$(cat /stream/status)" != 0
    '
docker run --rm -i \
    -e POSTGRES_USER -e POSTGRES_PASSWORD -e POSTGRES_DB -e DEBUG \
    -v "${stream_dir}:/stream" \
    --link "${NAME}":postgres \
    "${IMAGE}" \
    make import source=/stream/export.sql.gz host=postgres
[ "$(postgres make query-silent query='SELECT COUNT(*) FROM test')" = 1 ]
[ "$(postgres make query-silent query='SELECT COUNT(*) FROM test1')" = 0 ]
[ "$(postgres make query-silent query='SELECT COUNT(*) FROM test2')" = 0 ]
rm -rf "${stream_dir}"
echo "OK"

echo -n "Running import from URL source (.zip)... "
postgres make import source="https://s3.amazonaws.com/wodby-sample-files/postgres-import-test/export.zip"
echo "OK"

echo -n "Running import from URL source (.tar.gz)... "
postgres make import source="https://s3.amazonaws.com/wodby-sample-files/postgres-import-test/export.tar.gz"
echo "OK"

echo -n "Running managed initialization import... "
# What a backup of an earlier release looks like: objects in a schema named after the source
# database, owned by and granted to roles this server has never had.
cat > "${managed_import_dir}/import.sql" <<'SQL'
CREATE SCHEMA sourcedb;
ALTER SCHEMA sourcedb OWNER TO sourceadmin;
CREATE TABLE sourcedb.articles (id integer NOT NULL, title text);
ALTER TABLE sourcedb.articles OWNER TO sourceuser;
INSERT INTO sourcedb.articles VALUES (1, 'imported');
GRANT ALL ON SCHEMA sourcedb TO sourceuser;
SQL
chmod 644 "${managed_import_dir}/import.sql"
managed_cid="$(
	docker run -d \
		-e POSTGRES_PASSWORD \
		-e POSTGRES_USER \
		-e POSTGRES_DB='targetdb' \
		-e POSTGRES_INITDB_USER='targetuser' \
		-e POSTGRES_INITDB_PASSWORD='target-password' \
		-e POSTGRES_INITDB_SOURCE_DB='sourcedb' \
		-e DEBUG \
		-v "${managed_import_dir}:/wodby/import:ro" \
		--name "${NAME}-managed" \
		"${IMAGE}"
)"
docker run --rm -e POSTGRES_USER -e POSTGRES_PASSWORD -e POSTGRES_DB='targetdb' --link "${NAME}-managed":postgres "${IMAGE}" \
	make check-ready max_try=12 wait_seconds=5 host=postgres
managed_admin_sql() {
	sql "${NAME}-managed" "${POSTGRES_USER}" "${POSTGRES_PASSWORD}" "$1"
}
[ "$(managed_admin_sql targetdb <<< "SELECT schemaname, tableowner FROM pg_tables WHERE tablename = 'articles'")" = 'public|targetdb:owner' ]
[ "$(managed_admin_sql targetdb <<< "SELECT count(*) FROM pg_namespace WHERE nspname = 'sourcedb'")" = '0' ]
[ "$(managed_admin_sql postgres <<< "SELECT count(*) FROM pg_roles WHERE rolname IN ('sourceadmin', 'sourceuser')")" = '0' ]
[ "$(sql "${NAME}-managed" targetuser target-password targetdb <<< "INSERT INTO articles VALUES (2, 'written'); SELECT current_user, count(*) FROM articles GROUP BY 1")" = 'targetdb:owner|2' ]
managed_admin_sql postgres <<< "CREATE USER stranger PASSWORD 'stranger-password'"
if sql "${NAME}-managed" stranger stranger-password targetdb <<< 'SELECT 1' 2>/dev/null; then
	echo "A user without a grant can connect to the imported database" >&2
	exit 1
fi
echo "OK"

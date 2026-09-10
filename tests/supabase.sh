#!/usr/bin/env bash
set -euo pipefail
image=${IMAGE:-wodby/postgres:17-supabase-test}
prefix="supabase-test-$(date +%s)-${RANDOM}-$$"
network="$prefix-net"
source_container="$prefix-source"
target_container="$prefix-target"
volumes=("$prefix-source" "$prefix-target" "$prefix-backup" "$prefix-bad")
source_password=wodby_source_test_password_123
target_password=wodby_target_test_password_456
cleanup() {
    docker rm -f "$source_container" "$target_container" "$prefix-bad" >/dev/null 2>&1 || true
    for volume in "${volumes[@]}"; do docker volume rm "$volume" >/dev/null 2>&1 || true; done
    docker network rm "$network" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker network create "$network" >/dev/null
for volume in "${volumes[@]}"; do docker volume create "$volume" >/dev/null; done
start_db() {
    local name=$1 volume=$2 password=$3; shift 3
    docker run -d --name "$name" --network "$network" -v "$volume:/var/lib/postgresql" \
        -e POSTGRES_PASSWORD="$password" -e JWT_SECRET=wodby_test_jwt_secret_at_least_32_characters \
        "$@" "$image" >/dev/null
}
wait_db() {
    local name=$1 password=$2
    for attempt in $(seq 1 90); do
        if docker exec -e PGPASSWORD="$password" "$name" psql -h 127.0.0.1 -U supabase_admin -d postgres -Atc 'SELECT 1' >/dev/null 2>&1; then return; fi
        if [[ "$(docker inspect -f '{{.State.Running}}' "$name")" != true ]]; then break; fi
        sleep 2
    done
    docker logs --tail 70 "$name" >&2
    echo "Database did not become ready: $name" >&2; return 1
}
query() {
    local name=$1 password=$2 sql=$3 database=${4:-postgres}
    docker exec -e PGPASSWORD="$password" "$name" psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U supabase_admin -d "$database" -Atc "$sql"
}
start_db "$source_container" "${volumes[0]}" "$source_password"
wait_db "$source_container" "$source_password"
query "$source_container" "$source_password" "CREATE TABLE public.wodby_recovery(id integer PRIMARY KEY, value text); INSERT INTO public.wodby_recovery VALUES(1,'retained'); CREATE TABLE public.wodby_excluded(id integer); INSERT INTO public.wodby_excluded VALUES(1); CREATE ROLE wodby_owner LOGIN PASSWORD 'custom_role_password'; ALTER TABLE public.wodby_recovery OWNER TO wodby_owner; ALTER TABLE public.wodby_recovery ENABLE ROW LEVEL SECURITY; GRANT SELECT ON public.wodby_recovery TO anon,authenticated; CREATE POLICY authenticated_read ON public.wodby_recovery TO authenticated USING(true); SELECT vault.create_secret('recovery_secret','wodby_recovery'); INSERT INTO auth.users(id,email) VALUES('00000000-0000-0000-0000-000000000001','recovery@example.test'); CREATE TABLE storage.wodby_metadata(id text PRIMARY KEY); INSERT INTO storage.wodby_metadata VALUES('recovery');" >/dev/null
query "$source_container" "$source_password" "CREATE TABLE public.wodby_internal(id integer); INSERT INTO public.wodby_internal VALUES(42)" _supabase >/dev/null
key_before=$(docker exec "$source_container" sha256sum /etc/postgresql-custom/pgsodium_root.key | cut -d' ' -f1)
# A separate operational container has the same volume/remote-host contract as the service backup job.
docker run --rm --network "$network" -v "${volumes[0]}:/var/lib/postgresql" -v "${volumes[2]}:/backup" \
    -e POSTGRES_PASSWORD="$source_password" "$image" make backup host="$source_container" filepath=/backup/backup.tar.gz ignore=public.wodby_excluded
# Match the read-only extracted archive supplied by the service init import.
docker run --rm --entrypoint python3 -v "${volumes[2]}:/backup" "$image" -c 'import tarfile; tarfile.open("/backup/backup.tar.gz").extractall("/backup/extracted",filter="data")'
start_db "$target_container" "${volumes[1]}" "$target_password" -v "${volumes[2]}:/wodby/import-volume:ro" \
    --mount "type=volume,source=${volumes[2]},destination=/wodby/import,volume-subpath=extracted,readonly" -e SUPABASE_IMPORT_ON_INIT=1
wait_db "$target_container" "$target_password"
[[ $(query "$target_container" "$target_password" 'SELECT value FROM public.wodby_recovery') == retained ]]
[[ $(query "$target_container" "$target_password" 'SELECT count(*) FROM public.wodby_excluded') == 0 ]]
[[ $(query "$target_container" "$target_password" "SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='wodby_recovery'") == recovery_secret ]]
[[ $(query "$target_container" "$target_password" 'SELECT id FROM public.wodby_internal' _supabase) == 42 ]]
[[ $(query "$target_container" "$target_password" "SELECT email FROM auth.users WHERE id='00000000-0000-0000-0000-000000000001'") == recovery@example.test ]]
[[ $(query "$target_container" "$target_password" "SELECT count(*) FROM storage.wodby_metadata WHERE id='recovery'") == 1 ]]
[[ $(query "$target_container" "$target_password" 'SET ROLE anon; SELECT count(*) FROM public.wodby_recovery' | tail -1) == 0 ]]
[[ $(query "$target_container" "$target_password" 'SET ROLE authenticated; SELECT count(*) FROM public.wodby_recovery' | tail -1) == 1 ]]
[[ $(docker exec "$target_container" sha256sum /etc/postgresql-custom/pgsodium_root.key | cut -d' ' -f1) == "$key_before" ]]
# Reserved role passwords follow the target environment; custom role passwords survive the import.
for role in postgres authenticator supabase_auth_admin supabase_storage_admin; do
    docker exec -e PGPASSWORD="$target_password" "$target_container" psql -h 127.0.0.1 -U "$role" -d postgres -Atc 'SELECT 1' >/dev/null
done
docker exec -e PGPASSWORD=custom_role_password "$target_container" psql -h 127.0.0.1 -U wodby_owner -d postgres -Atc 'SELECT 1' >/dev/null
docker restart "$target_container" >/dev/null
wait_db "$target_container" "$target_password"
[[ $(query "$target_container" "$target_password" 'SELECT count(*) FROM public.wodby_recovery') == 1 ]]
if docker exec "$target_container" make -f /usr/local/share/wodby/supabase-actions.mk import; then
    echo 'Live import was unexpectedly allowed' >&2; exit 1
fi
# A corrupted archive fails before PostgreSQL initializes the replacement volume.
docker run --rm --entrypoint python3 -v "${volumes[2]}:/backup" "$image" -c 'from pathlib import Path; p=Path("/backup/extracted/roles.sql"); p.write_text(p.read_text()+"-- corrupted\n")'
start_db "$prefix-bad" "${volumes[3]}" "$target_password" --mount "type=volume,source=${volumes[2]},destination=/wodby/import,volume-subpath=extracted,readonly" -e SUPABASE_IMPORT_ON_INIT=1
[[ $(docker wait "$prefix-bad") != 0 ]]
docker run --rm --entrypoint sh -v "${volumes[3]}:/volume" "$image" -c 'test ! -f /volume/data/PG_VERSION'
docker rm "$prefix-bad" >/dev/null
# Failed restore must never turn into a successful partial database on restart.
docker run --rm --entrypoint python3 -v "${volumes[2]}:/backup" "$image" -c 'import json,hashlib,pathlib; p=pathlib.Path("/backup/extracted"); f=p/"roles.sql"; f.write_text(f.read_text()+"\nSELECT missing_restore_function();\n"); m=json.loads((p/"backup.json").read_text()); m["files"]["roles.sql"]=hashlib.sha256(f.read_bytes()).hexdigest(); (p/"backup.json").write_text(json.dumps(m))'
start_db "$prefix-bad" "${volumes[3]}" "$target_password" --mount "type=volume,source=${volumes[2]},destination=/wodby/import,volume-subpath=extracted,readonly" -e SUPABASE_IMPORT_ON_INIT=1
[[ $(docker wait "$prefix-bad") != 0 ]]
docker start "$prefix-bad" >/dev/null
[[ $(docker wait "$prefix-bad") != 0 ]]
docker logs "$prefix-bad" 2>&1 | tail -3 | grep -q 'Previous initialization or import failed'
echo 'Supabase fresh startup, backup, import, roles, RLS, Vault, Auth and Storage schema data, exclusions and restart checks passed.'

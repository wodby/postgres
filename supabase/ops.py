#!/usr/bin/env python3
"""Supabase operations for the pinned PostgreSQL bundle; imports run only on a fresh volume."""
import hashlib
import json
import os
from pathlib import Path
import pwd
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time

ROOT = Path('/var/lib/postgresql')
DATA = ROOT / 'data'
KEYS = ROOT / 'wodby-keys'
PENDING = ROOT / '.wodby-initialization-pending'
COMPLETE = ROOT / '.wodby-import-complete'
IMPORT = Path('/wodby/import')
STAGE = ROOT / 'wodby-import'
FORMAT = 'wodby-supabase-v1'
BASE = '17.6.1.136'


def run(args, *, capture=False, database=None, text=None):
    env = os.environ.copy()
    env.setdefault('PGPASSWORD', env.get('POSTGRES_PASSWORD', ''))
    if database is not None:
        env['PGDATABASE'] = database
    return subprocess.run(args, env=env, input=text, text=True, check=True,
                          stdout=subprocess.PIPE if capture else None).stdout


def sql(query=None, *, file=None, database=None):
    args = ['psql', '--no-psqlrc', '--no-password', '-v', 'ON_ERROR_STOP=1', '-At']
    args += ['-f', str(file)] if file else ['-c', query]
    return run(args, capture=True, database=database)


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def validate(directory):
    """Validate the complete extracted bundle before any database or key mutation."""
    manifest = directory / 'backup.json'
    if manifest.is_symlink() or not manifest.is_file():
        raise ValueError('Backup manifest must be a regular file')
    data = json.loads(manifest.read_text())
    if not isinstance(data, dict) or not isinstance(data.get('files'), dict):
        raise ValueError('Invalid backup manifest')
    if data.get('format') != FORMAT or data.get('base') != BASE:
        raise ValueError('Import requires a backup from the same Supabase PostgreSQL bundle')
    databases = data.get('databases')
    if (not isinstance(databases, list) or not databases or
            any(not isinstance(n, str) or not n or '\x00' in n for n in databases) or
            len(set(databases)) != len(databases) or 'postgres' not in databases or
            any(n in ('template0', 'template1') for n in databases)):
        raise ValueError('Invalid database inventory')
    expected = {'roles.sql', 'pgsodium_root.key'} | {f'db-{i}.dump' for i in range(len(databases))}
    if set(data.get('files', {})) != expected:
        raise ValueError('Incomplete backup file inventory')
    for name in expected:
        path = directory / name
        if path.is_symlink() or not path.is_file() or digest(path) != data['files'][name]:
            raise ValueError('Backup file is missing or corrupt: ' + name)
    if not re.fullmatch('[0-9a-fA-F]{64}', (directory / 'pgsodium_root.key').read_text().strip()):
        raise ValueError('Invalid database encryption key')
    return data


def prepare():
    """Keep keys on the replacement data volume and fail closed after incomplete initialization."""
    if os.environ.get('PGDATA', str(DATA)) != str(DATA):
        raise ValueError('The Supabase variant requires PGDATA=/var/lib/postgresql/data')
    if os.environ.get('POSTGRES_USER', 'supabase_admin') != 'supabase_admin':
        raise ValueError('The Supabase variant requires POSTGRES_USER=supabase_admin')
    if os.environ.get('POSTGRES_DB', 'postgres') != 'postgres':
        raise ValueError('The Supabase variant requires POSTGRES_DB=postgres')
    if (DATA / 'PG_VERSION').exists() and PENDING.exists():
        raise ValueError('Previous initialization or import failed; retry using a fresh volume')
    if (DATA / 'PG_VERSION').exists() and not (KEYS / 'pgsodium_root.key').is_file():
        raise ValueError('Database encryption key is missing; restore the matching key before startup')
    importing = os.environ.get('SUPABASE_IMPORT_ON_INIT') == '1'
    if importing:
        validate(IMPORT)
        if (DATA / 'PG_VERSION').exists():
            if not COMPLETE.is_file() or COMPLETE.read_text() != digest(IMPORT / 'backup.json'):
                raise ValueError('Import is only supported on a fresh volume')
            return
    if not (DATA / 'PG_VERSION').exists():
        ROOT.mkdir(parents=True, exist_ok=True)
        KEYS.mkdir(mode=0o700, exist_ok=True)
        if importing:
            shutil.copyfile(IMPORT / 'pgsodium_root.key', KEYS / 'pgsodium_root.key')
            STAGE.mkdir(mode=0o700, exist_ok=True)
            bundle = validate(IMPORT)
            for name in [*bundle['files'], 'backup.json']:
                shutil.copyfile(IMPORT / name, STAGE / name)
        PENDING.touch()
        if os.geteuid() == 0:
            account = pwd.getpwnam('postgres')
            paths = [ROOT, KEYS, PENDING, *KEYS.iterdir()]
            if importing:
                paths += [STAGE, *STAGE.iterdir()]
            for path in paths:
                os.chown(path, account.pw_uid, account.pw_gid)
        for path in KEYS.iterdir():
            path.chmod(0o600)


def backup():
    """Produce one checksummed logical bundle, including the root encryption key."""
    destination = os.environ.get('WODBY_BACKUP_FILE')
    if not destination:
        raise ValueError('filepath is required')
    if int(sql('SHOW server_version_num').strip()) // 10000 != 17:
        raise ValueError('Backup requires PostgreSQL 17')
    if sql("SELECT count(*) FROM pg_roles WHERE rolname ~ E'[\\n\\r]'").strip() != '0':
        raise ValueError('Backup does not support role names containing newlines')
    databases = json.loads(sql("SELECT json_agg(datname ORDER BY datname) FROM pg_database WHERE NOT datistemplate"))
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    ignore = [p for p in os.environ.get('WODBY_BACKUP_IGNORE', '').split(';') if p]
    with tempfile.TemporaryDirectory(prefix='.supabase-backup-', dir=destination.parent) as tmp:
        stage = Path(tmp)
        roles = "CREATE FUNCTION pg_temp.ensure_role(n text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname=n) THEN EXECUTE format('CREATE ROLE %I',n); END IF; END $$;\n"
        roles += sql("SELECT format('SELECT pg_temp.ensure_role(%L);',rolname) FROM pg_roles WHERE rolname !~ '^pg_' ORDER BY rolname")
        original = run(['pg_dumpall', '--roles-only'], capture=True)
        roles += '\n'.join(line for line in original.splitlines() if not line.startswith('CREATE ROLE ')) + '\n'
        (stage / 'roles.sql').write_text(roles)
        for i, name in enumerate(databases):
            print(f'Backing up database {i + 1}/{len(databases)}', flush=True)
            run(['pg_dump', '--format=custom', '--file=' + str(stage / f'db-{i}.dump'),
                 *['--exclude-table-data=' + p for p in ignore]], database=name)
        shutil.copyfile(KEYS / 'pgsodium_root.key', stage / 'pgsodium_root.key')
        manifest = {'format': FORMAT, 'base': BASE, 'databases': databases,
                    'files': {p.name: digest(p) for p in stage.iterdir()}}
        (stage / 'backup.json').write_text(json.dumps(manifest, sort_keys=True))
        validate(stage)
        archive = stage / 'backup.tar.gz'
        with tarfile.open(archive, 'w:gz') as tar:
            for name in [*manifest['files'], 'backup.json']:
                tar.add(stage / name, arcname=name)
        os.replace(archive, destination)
    print('Backup prepared. Save matching application tokens and storage objects separately.')


def restore(directory):
    """Restore only during fresh initialization, before the database accepts TCP connections."""
    if not PENDING.exists() or os.environ.get('PGHOST') != '/var/run/postgresql':
        raise ValueError('Import must run during fresh initialization; use the service import workflow')
    data = validate(directory)
    if digest(KEYS / 'pgsodium_root.key') != data['files']['pgsodium_root.key']:
        raise ValueError('Encryption key must be installed before database initialization')
    sql(file=directory / 'roles.sql')
    for i, name in enumerate(data['databases']):
        print(f'Restoring database {i + 1}/{len(data["databases"])}', flush=True)
        literal = "'" + name.replace("'", "''") + "'"
        create = sql("SELECT format('CREATE DATABASE %I', " + literal + ") WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname=" + literal + ')')
        if create.strip():
            sql(create, database='template1')
        connection = "dbname='" + name.replace('\\', '\\\\').replace("'", "\\'") + "'"
        run(['pg_restore', '--dbname=' + connection, '--clean', '--if-exists', '--exit-on-error', str(directory / f'db-{i}.dump')], database=name)
    # Supabase-owned logins must agree with this environment's configured password after import.
    sql(file=Path('/docker-entrypoint-initdb.d/init-scripts/99-roles.sql'))
    run(['psql', '--no-psqlrc', '--no-password', '-v', 'ON_ERROR_STOP=1'], text=r"""\getenv pgpass POSTGRES_PASSWORD
ALTER ROLE supabase_admin PASSWORD :'pgpass';
ALTER ROLE postgres PASSWORD :'pgpass';
""")
    sql(file=Path('/docker-entrypoint-initdb.d/init-scripts/99-jwt.sql'))
    COMPLETE.write_text(digest(directory / 'backup.json'))


def finish_init():
    if os.environ.get('SUPABASE_IMPORT_ON_INIT') == '1':
        restore(STAGE)
        shutil.rmtree(STAGE)
    PENDING.unlink()
    print('Supabase initialization and optional import completed')


def main():
    os.umask(0o077)
    action = sys.argv[1]
    if action == 'prepare':
        prepare()
    elif action == 'finish-init':
        finish_init()
    elif action == 'backup':
        backup()
    elif action == 'import':
        # Wodby's init import extracts archives into a read-only directory before starting this image.
        restore(Path(os.environ.get('WODBY_IMPORT_SOURCE') or str(STAGE)))
    elif action in ('query', 'query-silent'):
        query = os.environ.get('WODBY_QUERY')
        if not query:
            raise ValueError('query is required')
        print(sql(query), end='')
    elif action == 'check-ready':
        for attempt in range(int(os.environ.get('WODBY_MAX_TRY', '1'))):
            try:
                sql("SELECT 'auth'::regnamespace, 'storage'::regnamespace, '_realtime'::regnamespace")
                return
            except subprocess.CalledProcessError:
                if attempt + 1 >= int(os.environ.get('WODBY_MAX_TRY', '1')):
                    raise
                time.sleep(float(os.environ.get('WODBY_WAIT_SECONDS', '1')))
    else:
        raise ValueError('Unsupported Supabase operation')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, json.JSONDecodeError, subprocess.CalledProcessError) as error:
        print('Supabase operation failed: ' + str(error), file=sys.stderr)
        sys.exit(1)

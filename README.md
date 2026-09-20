# PostgreSQL Docker Container Image

[![Build Status](https://github.com/wodby/postgres/workflows/Build%20docker%20image/badge.svg)](https://github.com/wodby/postgres/actions)
[![Docker Pulls](https://img.shields.io/docker/pulls/wodby/postgres.svg)](https://hub.docker.com/r/wodby/postgres)
[![Docker Stars](https://img.shields.io/docker/stars/wodby/postgres.svg)](https://hub.docker.com/r/wodby/postgres)

## Docker Images

❗For better reliability we release images with stability tags (`wodby/postgres:18-X.X.X`) which correspond to [git tags](https://github.com/wodby/postgres/releases). We strongly recommend using images only with stability tags. 

Overview:

- All images are based on Alpine Linux
- Base image: [postgres](https://github.com/docker-library/postgres)
- [GitHub actions builds](https://github.com/wodby/postgres/actions) 
- [Docker Hub](https://hub.docker.com/r/wodby/postgres)

[_(Dockerfile)_]: https://github.com/wodby/postgres/tree/master/Dockerfile

Supported tags and respective `Dockerfile` links:

- `18`, `latest` [_(Dockerfile)_]
- `18-postgis`, `postgis` [_(Dockerfile)_]
- `17` [_(Dockerfile)_]
- `17-postgis` [_(Dockerfile)_]
- `16` [_(Dockerfile)_]
- `16-postgis` [_(Dockerfile)_]
- `15` [_(Dockerfile)_]
- `15-postgis` [_(Dockerfile)_]
- `14` [_(Dockerfile)_]
- `14-postgis` [_(Dockerfile)_]

All images built for `linux/amd64` and `linux/arm64`

## Bundled pgvector

All PostgreSQL and PostGIS images bundle pgvector `0.8.6`. The `vector`
extension is not enabled by default. Add it to `POSTGRES_DB_EXTENSIONS` when
needed:

```bash
docker run --rm \
  -e POSTGRES_PASSWORD=password \
  -e POSTGRES_DB_EXTENSIONS=vector \
  wodby/postgres:18
```

Configured extensions are installed both in the initial database and in
databases created later through the `create-db` orchestration action.

## PostGIS Tags

Plain tags (`18`, `17`, and so on) do not include PostGIS.

PostGIS tags (`18-postgis`, `17-postgis`, and so on) bundle PostGIS and default `POSTGRES_DB_EXTENSIONS` to:

```bash
postgis,postgis_raster,postgis_sfcgal,fuzzystrmatch,address_standardizer,address_standardizer_data_us,postgis_tiger_geocoder,postgis_topology
```

That means a container started from `wodby/postgres:18-postgis` or `wodby/postgres:postgis` will create the PostGIS extension set during initialization by default.

To override the default set:

```bash
docker run --rm \
  -e POSTGRES_PASSWORD=password \
  -e POSTGRES_DB_EXTENSIONS=postgis \
  wodby/postgres:18-postgis
```

Bundled PostGIS versions for the `*-postgis` tags:

- PostgreSQL `14`-`17`: PostGIS `3.5.7`
- PostgreSQL `18`: PostGIS `3.6.4`

## Environment Variables

| Variable                                | Default Value        | Description        |
|-----------------------------------------|----------------------|--------------------|
| `POSTGRES_CHECKPOINT_COMPLETION_TARGET` | `0.7`                |                    |
| `POSTGRES_CHECKPOINT_SEGMENTS`          | `32`                 | <=9.4              |
| `POSTGRES_DATESTYLE`                    | `iso, mdy`           |                    |
| `POSTGRES_DB`                           | `postgres`           |                    |
| `POSTGRES_DEFAULT_STATISTICS_TARGET`    | `100`                |                    |
| `POSTGRES_DEFAULT_TEXT_SEARCH_CONFIG`   | `pg_catalog.english` |                    |
| `POSTGRES_EFFECTIVE_CACHE_SIZE`         | `1GB`                |                    |
| `POSTGRES_DB_EXTENSIONS`                |                      | Separated by comma |
| `POSTGRES_INITDB_PASSWORD`              |                      | Password for the optional role created before initialization imports |
| `POSTGRES_INITDB_SOURCE_DB`             |                      | Database an imported dump was taken from, see [imports](#imports) |
| `POSTGRES_INITDB_USER`                  |                      | Optional role created before initialization imports |
| `POSTGRES_LAYOUT_LOCK_TIMEOUT`          | `10s`                | How long a [conversion](#databases-created-by-earlier-releases) waits for a lock |
| `POSTGRES_LC_MESSAGES`                  | `en_US.utf8`         |                    |
| `POSTGRES_LC_MONETARY`                  | `en_US.utf8`         |                    |
| `POSTGRES_LC_NUMERIC`                   | `en_US.utf8`         |                    |
| `POSTGRES_LC_TIME`                      | `en_US.utf8`         |                    |
| `POSTGRES_LOG_TIMEZONE`                 | `UTC`                |                    |
| `POSTGRES_MAINTENANCE_WORK_MEM`         | `128MB`              |                    |
| `POSTGRES_MAX_CONNECTIONS`              | `100`                |                    |
| `POSTGRES_MAX_WAL_SIZE`                 | `2GB`                | >=9.5              |
| `POSTGRES_MIN_WAL_SIZE`                 | `1GB`                | >=9.5              |
| `POSTGRES_SHARED_BUFFERS`               | `512MB`              |                    |
| `POSTGRES_SHARED_MEMORY_TYPE`           | `posix`              | >=9.4              |
| `POSTGRES_SHARED_PRELOAD_LIBRARIES`     |                      | Comma-separated libraries loaded when PostgreSQL starts |
| `POSTGRES_TIMEZONE`                     | `UTC`                |                    |
| `POSTGRES_PASSWORD`                     |                      | REQUIRED           |
| `POSTGRES_USER`                         | `postgres`           |                    |
| `POSTGRES_WAL_BUFFERS`                  | `16MB`               |                    |
| `POSTGRES_WORK_MEM`                     | `5MB`                |                    |

`POSTGRES_INITDB_USER` and `POSTGRES_INITDB_PASSWORD` must be set together. They do not replace the `POSTGRES_USER`
cluster administrator.

## Database Access

`create-db` gives every database its own owner role, named `<db>:owner`, which cannot log in. `grant-user-db` makes a
user a member of that role and has the user's sessions in that database act as it. As a result:

- Tables and other objects are created in the `public` schema, including by clients that select `public` themselves.
- Every object belongs to the owner role, whichever user created it, so all users granted access to a database share
  its data. In such a session `current_user` is the owner role and `session_user` is the user that logged in.
- `revoke-user-db` removes all access. A revoked user owns nothing and can be dropped right away.
- Only users granted access can connect to a database created by `create-db`.

Backups contain no role names and no grants, so a backup can be imported into a database with a different name and
different users. Access to imported data comes from the owner role of the database it is imported into.

### Imports

Files mounted at `/wodby/import` are loaded into `POSTGRES_DB` when the data directory is initialized. With
`POSTGRES_INITDB_USER` set, that user is granted access to the database and the imported objects are handed to its
owner role.

A dump may name roles this server does not have, as a plain `pg_dump` does for the owner of every object. Such roles
exist only while the dump is loaded. A dump that creates roles itself is loaded as it is.

### Databases created by earlier releases

Releases 1.40 to 1.47 created a schema named after the database and pointed each user's `search_path` at it.
`adopt-dbs` converts every such database of a server and is meant to run once after the server is upgraded; the next
`create-db` or `grant-user-db` for such a database converts it as well. A conversion means: objects move to `public`, the users that had access
become members of the owner role, and the schema and the `search_path` settings are removed. Objects owned by roles
that were never granted access are left alone.

- Applications keep working during the conversion and need no restart, as long as they do not name the schema.
  An application that does, in its queries, in a `search_path` or schema setting, or in the body of a function, must
  be changed to use `public`.
- Objects move one statement at a time, each waiting up to `POSTGRES_LAYOUT_LOCK_TIMEOUT` for a lock. If a long
  transaction makes a statement time out, the action fails, the database stays usable, and repeating the action
  continues where it stopped.
- A backup of such a database keeps its objects in the schema named after it. Importing that backup under another
  database name requires `POSTGRES_INITDB_SOURCE_DB` set to the original name, so that schema is converted too.

## Orchestration Actions

Usage:
```
make COMMAND [params ...]
 
commands:
    import source=</path/to/dump.zip or http://example.com/url/to/dump.sql.gz> [user password db host  binary] 
    backup filepath=</path/to/backup.sql.gz> [user password host db ignore=<"table1;table2"> nice ionice] 
    query query=<SELECT 1> [user password db host] 
    query-silent query=<SELECT 1> [user password db host]
    create-db name enconding lc_collate lc_ctype
      also creates the owner role of the database
    drop-db name
      also drops the owner role of the database
    adopt-dbs
      converts the databases created by earlier releases, leaves all others alone
    create-user username password
    drop-user username
    grant-user-db username db
      gives the user full access to the database and the objects of its other users
    revoke-user-db username db
      removes all access of the user to the database
    check-ready [user password db host max_try wait_seconds delay_seconds]  
    
default params values:
    user $POSTGRES_USER
    password $POSTGRES_PASSWORD
    db $POSTGRES_DB
    host localhost
    max_try 1
    wait_seconds 1
    delay_seconds 0
    ignore ""
    binary 0
    nice 10
    ionice 7    
```

`create-user` is safe to retry when the existing role accepts the requested password, but fails on a same-named role
with different credentials rather than replacing it.

`create-db`, `grant-user-db`, `revoke-user-db` and `adopt-dbs` are safe to retry. See [database access](#database-access) for what
they set up. `import` keeps the owner role and the users of the database it replaces.

## Deployment

Deploy PostgreSQL to your server via [![Wodby](https://www.google.com/s2/favicons?domain=wodby.com) Wodby](https://wodby.com/stacks/postgres).

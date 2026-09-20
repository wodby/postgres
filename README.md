# PostgreSQL Docker Container Image

[![Build Status](https://github.com/wodby/postgres/workflows/Build%20docker%20image/badge.svg)](https://github.com/wodby/postgres/actions)
[![Docker Pulls](https://img.shields.io/docker/pulls/wodby/postgres.svg)](https://hub.docker.com/r/wodby/postgres)
[![Docker Stars](https://img.shields.io/docker/stars/wodby/postgres.svg)](https://hub.docker.com/r/wodby/postgres)

## Docker Images

Use image revision tags such as `wodby/postgres:18-rN` to select a Wodby image revision.
Major and minor tags use the repository release number, starting at `r0`. Full-version tags such as
`wodby/postgres:18.6-r0` start at `r0` for each exact upstream version.
Every published versioned revision tag has a matching annotated Git tag pointing to its release commit.
Existing tags remain available after support for their major or minor version ends.
See [release tags](https://github.com/wodby/postgres/tags) for available revisions and the [image revision policy](https://github.com/wodby/images#image-revisions) for upgrade guidance.
Previously published image tags remain available.

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
| `POSTGRES_INITDB_USER`                  |                      | Optional role created before initialization imports |
| `POSTGRES_LAYOUT_LOCK_TIMEOUT`          | `10s`                | How long `convert-db` waits for a lock |
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
    convert-db name [schema]
      moves a database created by releases 1.40 to 1.47 to the public schema
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

`create-db`, `grant-user-db`, `revoke-user-db` and `convert-db` are safe to retry. See [database access](#database-access) for what
they set up. `import` keeps the owner role and the users of the database it replaces.

## Deployment

Deploy PostgreSQL to your server via [![Wodby](https://www.google.com/s2/favicons?domain=wodby.com) Wodby](https://wodby.com/stacks/postgres).

## Building with pinned base images

Build with the Makefile to use the base image digests in `base-images.mk`. Local
builds and CI resolve the same version and variant to the same multi-platform
image. A version without a pin fails before the build starts.

When adding a supported base version or variant, add its image index digest to
`base-images.mk`. For a custom build, override `BASE_IMAGE` with a complete
`repository:tag@sha256:...` reference.

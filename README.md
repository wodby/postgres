# Generic PostgreSQL docker container image

[![Build Status](https://travis-ci.org/wodby/postgres.svg?branch=master)](https://travis-ci.org/wodby/postgres)
[![Docker Pulls](https://img.shields.io/docker/pulls/wodby/postgres.svg)](https://hub.docker.com/r/wodby/postgres)
[![Docker Stars](https://img.shields.io/docker/stars/wodby/postgres.svg)](https://hub.docker.com/r/wodby/postgres)

[![Wodby Slack](https://www.google.com/s2/favicons?domain=www.slack.com) Join us on Slack](https://slack.wodby.com/)

## Supported tags and respective `Dockerfile` links:

- [`9.6`, `latest` (*9.6/Dockerfile*)](https://github.com/wodby/postgres/tree/master/9.6/Dockerfile)
- [`9.5`, `latest` (*9.5/Dockerfile*)](https://github.com/wodby/postgres/tree/master/9.5/Dockerfile)
- [`9.4`, `latest` (*9.4/Dockerfile*)](https://github.com/wodby/postgres/tree/master/9.4/Dockerfile)
- [`9.3`, `latest` (*9.3/Dockerfile*)](https://github.com/wodby/postgres/tree/master/9.3/Dockerfile)
- [`9.2`, `latest` (*9.2/Dockerfile*)](https://github.com/wodby/postgres/tree/master/9.2/Dockerfile)

## Environment Variables Available for Customization

| Environment Variable | Default Value | Description |
| -------------------- | --------------| ----------- |
| POSTGRES_CHECKPOINT_COMPLETION_TARGET | 0.7                | |
| POSTGRES_CHECKPOINT_SEGMENTS          | 32                 | <=9.4 |
| POSTGRES_DATESTYLE                    | iso, mdy           | |
| POSTGRES_DB                           | postgres           | |
| POSTGRES_DEFAULT_STATISTICS_TARGET    | 100                | |
| POSTGRES_DEFAULT_TEXT_SEARCH_CONFIG   | pg_catalog.english | |
| POSTGRES_EFFECTIVE_CACHE_SIZE         | 1GB                | |
| POSTGRES_LC_MESSAGES                  | en_US.utf8         | |
| POSTGRES_LC_MONETARY                  | en_US.utf8         | |
| POSTGRES_LC_NUMERIC                   | en_US.utf8         | |
| POSTGRES_LC_TIME                      | en_US.utf8         | |
| POSTGRES_LOG_TIMEZONE                 | UTC                | |
| POSTGRES_MAINTENANCE_WORK_MEM         | 128MB              | |
| POSTGRES_MAX_CONNECTIONS              | 100                | |
| POSTGRES_MAX_WAL_SIZE                 | 2GB                | >=9.5 |
| POSTGRES_MIN_WAL_SIZE                 | 1GB                | >=9.5 |
| POSTGRES_SHARED_BUFFERS               | 512MB              | |
| POSTGRES_SHARED_MEMORY_TYPE           | posix              | >=9.4 |
| POSTGRES_TIMEZONE                     | UTC                | | 
| POSTGRES_PASSWORD                     |                    | REQUIRED |
| POSTGRES_USER                         | postgres           | |
| POSTGRES_WAL_BUFFERS                  | 16MB               | |
| POSTGRES_WORK_MEM                     | 5MB                | |

## Actions

Usage:
```
make COMMAND [params ...]
 
commands:
    import source=</path/to/dump.zip or http://example.com/url/to/dump.sql.gz> [user password db host  binary] 
    backup filepath=</path/to/backup.sql.gz> [user password host db ignore=<"table1;table2">] 
    query query=<SELECT 1> [user password db host] 
    query-silent query=<SELECT 1> [user password db host]
    check-ready [user password db host max_try wait_seconds]  
    
default params values:
    user $POSTGRES_USER
    password $POSTGRES_PASSWORD
    db $POSTGRES_DB
    host localhost
    max_try 1
    wait_seconds = 1
    ignore ""
    binary 0
```

Examples:

```bash
# Check if PostgreSQL is ready
docker exec -ti [ID] make check-ready -f /usr/local/bin/actions.mk

# Run query
docker exec -ti [ID] make query query="CREATE TABLE test (a Numeric, b Numeric, c VARCHAR(255))" -f /usr/local/bin/actions.mk

# Backup default database
docker exec -ti [ID] make backup filepath="/path/to/mounted/dir/backup.sql.gz" -f /usr/local/bin/actions.mk

# Import from file
docker exec -ti [ID] make import source="/path/to/mounted/dir/export.sql.gz" -f /usr/local/bin/actions.mk

# Import from URL
docker exec -ti [ID] make import source="https://example.com/url/to/sql/dump.zip" -f /usr/local/bin/actions.mk
```

You can skip -f option if you use run instead of exec. 

## Using in Production

Deploy PostgreSQL container to your own server via [![Wodby](https://www.google.com/s2/favicons?domain=wodby.com) Wodby](https://wodby.com).

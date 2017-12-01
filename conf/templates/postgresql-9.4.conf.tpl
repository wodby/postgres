listen_addresses = '*'

max_connections = {{ getenv "POSTGRES_MAX_CONNECTIONS" "100" }}

shared_buffers = {{ getenv "POSTGRES_SHARED_BUFFERS" "512MB" }}

work_mem = {{ getenv "POSTGRES_WORK_MEM" "5MB" }}
maintenance_work_mem = {{ getenv "POSTGRES_MAINTENANCE_WORK_MEM" "128MB" }}
dynamic_shared_memory_type = {{ getenv "POSTGRES_SHARED_MEMORY_TYPE" "posix" }}

wal_buffers = {{ getenv "POSTGRES_WAL_BUFFERS" "16MB" }}

checkpoint_completion_target = {{ getenv "POSTGRES_CHECKPOINT_COMPLETION_TARGET" "0.7" }}
effective_cache_size = {{ getenv "POSTGRES_EFFECTIVE_CACHE_SIZE" "1GB" }}
default_statistics_target = {{ getenv "POSTGRES_DEFAULT_STATISTICS_TARGET" "100" }}

log_timezone = '{{ getenv "POSTGRES_LOG_TIMEZONE" "UTC" }}'
datestyle = '{{ getenv "POSTGRES_DATESTYLE" "iso, mdy" }}'
timezone = '{{ getenv "POSTGRES_TIMEZONE" "UTC" }}'

lc_messages = '{{ getenv "POSTGRES_LC_MESSAGES" "en_US.utf8" }}'
lc_monetary = '{{ getenv "POSTGRES_LC_MONETARY" "en_US.utf8" }}'
lc_numeric = '{{ getenv "POSTGRES_LC_NUMERIC" "en_US.utf8" }}'
lc_time = '{{ getenv "POSTGRES_LC_TIME" "en_US.utf8" }}'

default_text_search_config = '{{ getenv "POSTGRES_DEFAULT_TEXT_SEARCH_CONFIG" "pg_catalog.english" }}'

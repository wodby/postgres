.PHONY: backup import query query-silent check-ready check-live
host ?= localhost
user ?= supabase_admin
db ?= postgres
ignore ?=
max_try ?= 1
wait_seconds ?= 1
export PGHOST = $(host)
export PGUSER = $(user)
export PGDATABASE = $(db)
export PGPASSWORD = $(POSTGRES_PASSWORD)
export WODBY_BACKUP_FILE = $(filepath)
export WODBY_BACKUP_IGNORE = $(ignore)
export WODBY_QUERY = $(query)
export WODBY_IMPORT_SOURCE = $(source)
export WODBY_MAX_TRY = $(max_try)
export WODBY_WAIT_SECONDS = $(wait_seconds)
backup:
	@supabase-ops backup
import:
	@supabase-ops import
query:
	@supabase-ops query
query-silent:
	@supabase-ops query-silent
check-ready:
	@supabase-ops check-ready
check-live:
	@echo OK

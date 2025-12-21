.PHONY: import backup query query-silent query-root check-ready check-live

check_defined = \
    $(strip $(foreach 1,$1, \
        $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
    $(if $(value $1),, \
      $(error Required parameter is missing: $1$(if $2, ($2))))

user ?= $(POSTGRES_USER)
password ?= $(POSTGRES_PASSWORD)
db ?= $(POSTGRES_DB)
host ?= localhost
max_try ?= 1
wait_seconds ?= 1
delay_seconds ?= 0
binary ?= 0
ignore ?= ""
nice ?= 10
ionice ?= 7

default: query

import:
	$(call check_defined, source)
	import $(user) $(password) $(host) $(db) $(source) $(binary)

backup:
	$(call check_defined, filepath)
	backup $(user) $(password) $(host) $(db) $(filepath) "$(ignore)" $(nice) $(ionice)

query:
	$(call check_defined, query)
	PGPASSWORD=$(password) psql -U$(user) -h$(host) -d$(db) -c "$(query)"

query-silent:
	$(call check_defined, query)
	@PGPASSWORD=$(password) psql -tA -U$(user) -h$(host) -d$(db) -c "$(query)"

create-db:
	$(call check_defined, name)
	$(eval override encoding := $(or $(encoding),UTF8))
	$(eval override lc_collate := $(or $(lc_collate),en_US.utf8))
	$(eval override lc_ctype := $(or $(lc_ctype),en_US.utf8))
	$(eval override name := $(shell echo "${name}" | tr -d \'\"))
	PGPASSWORD=$(POSTGRES_PASSWORD) psql -U$(POSTGRES_USER) -h$(host) -d postgres -c "CREATE DATABASE \"$(name)\" ENCODING '$(encoding)' LC_COLLATE '$(lc_collate)' LC_CTYPE '$(lc_ctype)';" 2>&1 | grep -v "already exists" || true
.PHONY: create-db

drop-db:
	$(call check_defined, name)
	$(eval override name := $(shell echo "${name}" | tr -d \'\"))
	PGPASSWORD=$(POSTGRES_PASSWORD) psql -U$(POSTGRES_USER) -h$(host) -d postgres -c "DROP DATABASE IF EXISTS \"$(name)\";"
.PHONY: drop-db

create-user:
	$(call check_defined, username, password)
	$(eval override password := $(shell echo "${password}" | tr -d \'\"))
	$(eval override username := $(shell echo "${username}" | tr -d \'\"))
	PGPASSWORD=$(POSTGRES_PASSWORD) psql -U$(POSTGRES_USER) -h$(host) -d postgres -c "DO \$$\$$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '$(username)') THEN CREATE USER \"$(username)\" WITH PASSWORD '$(password)'; END IF; END \$$\$$;"
.PHONY: create-user

drop-user:
	$(call check_defined, username)
	$(eval override username := $(shell echo "${username}" | tr -d \'\"))
	PGPASSWORD=$(POSTGRES_PASSWORD) psql -U$(POSTGRES_USER) -h$(host) -d postgres -c "DROP USER IF EXISTS \"$(username)\";"
.PHONY: drop-user

grant-user-db:
	$(call check_defined, username, db)
	$(eval override username := $(shell echo "${username}" | tr -d \'\"))
	$(eval override db := $(shell echo "${db}" | tr -d \'\"))
	PGPASSWORD=$(POSTGRES_PASSWORD) psql -U$(POSTGRES_USER) -h$(host) -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$(db)\" TO \"$(username)\";"
.PHONY: grant-user-db

revoke-user-db:
	$(call check_defined, username, db)
	$(eval override username := $(shell echo "${username}" | tr -d \'\"))
	$(eval override db := $(shell echo "${db}" | tr -d \'\"))
	PGPASSWORD=$(POSTGRES_PASSWORD) psql -U$(POSTGRES_USER) -h$(host) -d postgres -c "REVOKE ALL PRIVILEGES ON DATABASE \"$(db)\" FROM \"$(username)\";"
.PHONY: revoke-user-db

check-ready:
	wait_for_postgres $(user) $(password) $(db) $(host) $(max_try) $(wait_seconds) $(delay_seconds)

check-live:
	@echo "OK"

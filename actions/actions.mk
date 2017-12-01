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
	import.sh $(user) $(password) $(host) $(db) $(source) $(binary)

backup:
	$(call check_defined, filepath)
	backup.sh $(user) $(password) $(host) $(db) $(filepath) "$(ignore)" $(nice) $(ionice)

query:
	$(call check_defined, query)
	PGPASSWORD=$(password) psql -U$(user) -h$(host) -d$(db) -c "$(query)"

query-silent:
	$(call check_defined, query)
	@PGPASSWORD=$(password) psql -tA -U$(user) -h$(host) -d$(db) -c "$(query)"

check-ready:
	wait-for-postgres.sh $(user) $(password) $(db) $(host) $(max_try) $(wait_seconds) $(delay_seconds)

check-live:
	@echo "OK"

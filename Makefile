-include env_make

POSTGRES_VER ?= 15.3

# 10.2 => 10, 9.6.3 => 9.6
# http://www.databasesoup.com/2016/05/changing-postgresql-version-numbering.html
POSTGRES_MAJOR_VER ?= $(shell echo "$(POSTGRES_VER)" | sed -E 's/.[0-9]+$$//')

TAG ?= $(POSTGRES_MAJOR_VER)

PLATFORM ?= linux/amd64

REPO = wodby/postgres
NAME = postgres-$(POSTGRES_MAJOR_VER)

ifneq ($(STABILITY_TAG),)
    ifneq ($(TAG),latest)
        override TAG := $(TAG)-$(STABILITY_TAG)
    endif
endif

.PHONY: build buildx-push buildx-build buildx-build-amd64 test push shell run start stop logs clean release

default: build

build:
	docker build -t $(REPO):$(TAG) \
		--build-arg POSTGRES_VER=$(POSTGRES_VER) \
		--build-arg POSTGRES_MAJOR_VER=$(POSTGRES_MAJOR_VER) \
		./

# --load doesn't work with multiple platforms https://github.com/docker/buildx/issues/59
# we need to save cache to run tests first.
buildx-build-amd64:
	docker buildx build --platform linux/amd64 -t $(REPO):$(TAG) \
		--build-arg POSTGRES_VER=$(POSTGRES_VER) \
		--build-arg POSTGRES_MAJOR_VER=$(POSTGRES_MAJOR_VER) \
		--build-arg ALPINE_VER=$(ALPINE_VER) \
		--load \
		./

buildx-build:
	docker buildx build --platform $(PLATFORM) -t $(REPO):$(TAG) \
		--build-arg POSTGRES_VER=$(POSTGRES_VER) \
		--build-arg POSTGRES_MAJOR_VER=$(POSTGRES_MAJOR_VER) \
		--build-arg ALPINE_VER=$(ALPINE_VER) \
		./

buildx-push:
	docker buildx build --platform $(PLATFORM) --push -t $(REPO):$(TAG) \
		--build-arg POSTGRES_VER=$(POSTGRES_VER) \
		--build-arg POSTGRES_MAJOR_VER=$(POSTGRES_MAJOR_VER) \
		--build-arg ALPINE_VER=$(ALPINE_VER) \
		./

test:
	cd ./tests && NAME=$(NAME) IMAGE=$(REPO):$(TAG) ./run.sh

push:
	docker push $(REPO):$(TAG)

shell:
	docker run --rm --name $(NAME) -e POSTGRES_PASSWORD=password -i -t $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) /bin/bash

run:
	docker run --rm --name $(NAME) -e POSTGRES_PASSWORD=password $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) $(CMD)

start:
	docker run -d --name $(NAME) -e POSTGRES_PASSWORD=password $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG)

stop:
	docker stop $(NAME)

logs:
	docker logs $(NAME)

clean:
	-docker rm -f $(NAME)

check-configs:
	./check-configs.sh $(POSTGRES_VER) $(POSTGRES_MAJOR_VER)

release: build push

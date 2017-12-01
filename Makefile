-include env_make

POSTGRES_VER ?= 10.1
FROM_TAG = $(POSTGRES_VER)-alpine

# Remove minor version from tag
TAG ?= $(shell echo "${POSTGRES_VER}" | grep -oE '^[0-9]+\.[0-9]+?')

REPO = wodby/postgres
NAME = postgres-$(POSTGRES_VER)

ifneq ($(STABILITY_TAG),)
ifneq ($(TAG),latest)
    override TAG := $(TAG)-$(STABILITY_TAG)
endif
endif

.PHONY: build test push shell run start stop logs clean release

default: build

build:
	docker build -t $(REPO):$(TAG) --build-arg FROM_TAG=$(FROM_TAG) --build-arg POSTGRES_VER=$(POSTGRES_VER) ./

test:
	NAME=$(NAME) IMAGE=$(REPO):$(TAG) ./test.sh

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

release: build push

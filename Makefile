-include env_make

POSTGRES_VER ?= 18.1

# 10.2 => 10, 9.6.3 => 9.6
# http://www.databasesoup.com/2016/05/changing-postgresql-version-numbering.html
POSTGRES_MAJOR_VER ?= $(shell echo "$(POSTGRES_VER)" | sed -E 's/.[0-9]+$$//')

TAG ?= $(POSTGRES_MAJOR_VER)

PLATFORM ?= linux/arm64

REPO = wodby/postgres
NAME = postgres-$(POSTGRES_MAJOR_VER)

ifneq ($(STABILITY_TAG),)
    ifneq ($(TAG),latest)
        override TAG := $(TAG)-$(STABILITY_TAG)
    endif
endif

IMAGETOOLS_TAG ?= $(TAG)

ifneq ($(ARCH),)
	override TAG := $(TAG)-$(ARCH)
endif

.PHONY: build buildx-push buildx-build test push shell run start stop logs clean release

default: build

build:
	docker build -t $(REPO):$(TAG) \
		--build-arg POSTGRES_VER=$(POSTGRES_VER) \
		--build-arg POSTGRES_MAJOR_VER=$(POSTGRES_MAJOR_VER) \
		./

buildx-build:
	docker buildx build --platform $(PLATFORM) -t $(REPO):$(TAG) \
		--build-arg POSTGRES_VER=$(POSTGRES_VER) \
		--build-arg POSTGRES_MAJOR_VER=$(POSTGRES_MAJOR_VER) \
		--build-arg ALPINE_VER=$(ALPINE_VER) \
		--load \		
		./

buildx-push:
	docker buildx build --platform $(PLATFORM) --push -t $(REPO):$(TAG) \
		--build-arg POSTGRES_VER=$(POSTGRES_VER) \
		--build-arg POSTGRES_MAJOR_VER=$(POSTGRES_MAJOR_VER) \
		--build-arg ALPINE_VER=$(ALPINE_VER) \
		./

buildx-imagetools-create:
	docker buildx imagetools create -t $(REPO):$(IMAGETOOLS_TAG) \
				  $(REPO):$(TAG)-amd64 \
				  $(REPO):$(TAG)-arm64
.PHONY: buildx-imagetools-create 

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

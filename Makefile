-include env_make

POSTGRES_VER ?= 18.3
WITH_POSTGIS ?= 0

POSTGIS_DEFAULT_EXTENSIONS = postgis,postgis_raster,postgis_sfcgal,fuzzystrmatch,address_standardizer,address_standardizer_data_us,postgis_tiger_geocoder,postgis_topology

# 10.2 => 10, 9.6.3 => 9.6
# http://www.databasesoup.com/2016/05/changing-postgresql-version-numbering.html
POSTGRES_MAJOR_VER ?= $(shell echo "$(POSTGRES_VER)" | sed -E 's/.[0-9]+$$//')

ifeq ($(WITH_POSTGIS),1)
ifneq ($(filter $(POSTGRES_MAJOR_VER),14 15 16 17),)
POSTGIS_VERSION ?= 3.5.5
POSTGIS_SHA256 ?= fc3408c474662b5354c9569cfbd18172f2f4818c09945725b8d0089169925fb1
endif

ifeq ($(POSTGRES_MAJOR_VER),18)
POSTGIS_VERSION ?= 3.6.2
POSTGIS_SHA256 ?= 607a4d21c017e5283e15d2d977c9b7f575ddfc672afdee81fc84a2d823db4ba5
endif

ifndef POSTGIS_VERSION
$(error Unsupported POSTGRES_MAJOR_VER "$(POSTGRES_MAJOR_VER)" for bundled PostGIS)
endif
TAG_SUFFIX ?= -postgis
POSTGRES_DB_EXTENSIONS_DEFAULT ?= $(POSTGIS_DEFAULT_EXTENSIONS)
else
TAG_SUFFIX ?=
POSTGRES_DB_EXTENSIONS_DEFAULT ?=
endif

TAG ?= $(POSTGRES_MAJOR_VER)$(TAG_SUFFIX)

PLATFORM ?= linux/arm64

REPO = wodby/postgres
NAME = postgres-$(POSTGRES_MAJOR_VER)$(TAG_SUFFIX)

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
		--build-arg WITH_POSTGIS=$(WITH_POSTGIS) \
		--build-arg POSTGIS_VERSION=$(POSTGIS_VERSION) \
		--build-arg POSTGIS_SHA256=$(POSTGIS_SHA256) \
		--build-arg POSTGRES_DB_EXTENSIONS_DEFAULT=$(POSTGRES_DB_EXTENSIONS_DEFAULT) \
		./

buildx-build:
	docker buildx build --platform $(PLATFORM) -t $(REPO):$(TAG) \
		--build-arg POSTGRES_VER=$(POSTGRES_VER) \
		--build-arg POSTGRES_MAJOR_VER=$(POSTGRES_MAJOR_VER) \
		--build-arg WITH_POSTGIS=$(WITH_POSTGIS) \
		--build-arg POSTGIS_VERSION=$(POSTGIS_VERSION) \
		--build-arg POSTGIS_SHA256=$(POSTGIS_SHA256) \
		--build-arg POSTGRES_DB_EXTENSIONS_DEFAULT=$(POSTGRES_DB_EXTENSIONS_DEFAULT) \
		--build-arg ALPINE_VER=$(ALPINE_VER) \
		--load \		
		./

buildx-push:
	docker buildx build --platform $(PLATFORM) --push -t $(REPO):$(TAG) \
		--build-arg POSTGRES_VER=$(POSTGRES_VER) \
		--build-arg POSTGRES_MAJOR_VER=$(POSTGRES_MAJOR_VER) \
		--build-arg WITH_POSTGIS=$(WITH_POSTGIS) \
		--build-arg POSTGIS_VERSION=$(POSTGIS_VERSION) \
		--build-arg POSTGIS_SHA256=$(POSTGIS_SHA256) \
		--build-arg POSTGRES_DB_EXTENSIONS_DEFAULT=$(POSTGRES_DB_EXTENSIONS_DEFAULT) \
		--build-arg ALPINE_VER=$(ALPINE_VER) \
		./

buildx-imagetools-create:
	docker buildx imagetools create -t $(REPO):$(IMAGETOOLS_TAG) \
				  $(REPO):$(TAG)-amd64 \
				  $(REPO):$(TAG)-arm64
.PHONY: buildx-imagetools-create 

test:
	cd ./tests && NAME=$(NAME) IMAGE=$(REPO):$(TAG) TEST_POSTGIS=$(WITH_POSTGIS) ./run.sh

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

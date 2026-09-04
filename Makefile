-include env_make

POSTGRES_VER ?= 18.6
WITH_POSTGIS ?= 0
WITH_PGVECTOR ?= 0

POSTGIS_DEFAULT_EXTENSIONS = postgis,postgis_raster,postgis_sfcgal,fuzzystrmatch,address_standardizer,address_standardizer_data_us,postgis_tiger_geocoder,postgis_topology
PGVECTOR_DEFAULT_EXTENSIONS = vector
comma := ,

TAG_SUFFIX_DEFAULT =
POSTGRES_DB_EXTENSIONS_DEFAULT_VALUE =

# 10.2 => 10, 9.6.3 => 9.6
# http://www.databasesoup.com/2016/05/changing-postgresql-version-numbering.html
POSTGRES_MAJOR_VER ?= $(shell echo "$(POSTGRES_VER)" | sed -E 's/.[0-9]+$$//')

ifeq ($(WITH_POSTGIS),1)
ifneq ($(filter $(POSTGRES_MAJOR_VER),14 15 16 17),)
POSTGIS_VERSION ?= 3.5.7
POSTGIS_SHA256 ?= 22f99b7f72a123f69cadb39c1b48bb01752a942d5d7967f939dd6e224a005121
endif

ifeq ($(POSTGRES_MAJOR_VER),18)
POSTGIS_VERSION ?= 3.6.4
POSTGIS_SHA256 ?= 4f80e1a4d227f088ae818f79180debd5894c075615823e0f556f73479cf1f200
endif

ifndef POSTGIS_VERSION
$(error Unsupported POSTGRES_MAJOR_VER "$(POSTGRES_MAJOR_VER)" for bundled PostGIS)
endif
TAG_SUFFIX_DEFAULT := $(TAG_SUFFIX_DEFAULT)-postgis
POSTGRES_DB_EXTENSIONS_DEFAULT_VALUE := $(POSTGIS_DEFAULT_EXTENSIONS)
endif

ifeq ($(WITH_PGVECTOR),1)
PGVECTOR_VERSION ?= 0.8.6
PGVECTOR_SHA256 ?= 10bf9938906e5d643bbc4a7eea104b6f57ba4898e5b76b20e60484ea1d5a7f8f
TAG_SUFFIX_DEFAULT := $(TAG_SUFFIX_DEFAULT)-pgvector
POSTGRES_DB_EXTENSIONS_DEFAULT_VALUE := $(if $(POSTGRES_DB_EXTENSIONS_DEFAULT_VALUE),$(POSTGRES_DB_EXTENSIONS_DEFAULT_VALUE)$(comma),)$(PGVECTOR_DEFAULT_EXTENSIONS)
endif

TAG_SUFFIX ?= $(TAG_SUFFIX_DEFAULT)
POSTGRES_DB_EXTENSIONS_DEFAULT ?= $(POSTGRES_DB_EXTENSIONS_DEFAULT_VALUE)

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
		--build-arg WITH_PGVECTOR=$(WITH_PGVECTOR) \
		--build-arg PGVECTOR_VERSION=$(PGVECTOR_VERSION) \
		--build-arg PGVECTOR_SHA256=$(PGVECTOR_SHA256) \
		--build-arg POSTGRES_DB_EXTENSIONS_DEFAULT=$(POSTGRES_DB_EXTENSIONS_DEFAULT) \
		./

buildx-build:
	docker buildx build --platform $(PLATFORM) -t $(REPO):$(TAG) \
		--build-arg POSTGRES_VER=$(POSTGRES_VER) \
		--build-arg POSTGRES_MAJOR_VER=$(POSTGRES_MAJOR_VER) \
		--build-arg WITH_POSTGIS=$(WITH_POSTGIS) \
		--build-arg POSTGIS_VERSION=$(POSTGIS_VERSION) \
		--build-arg POSTGIS_SHA256=$(POSTGIS_SHA256) \
		--build-arg WITH_PGVECTOR=$(WITH_PGVECTOR) \
		--build-arg PGVECTOR_VERSION=$(PGVECTOR_VERSION) \
		--build-arg PGVECTOR_SHA256=$(PGVECTOR_SHA256) \
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
		--build-arg WITH_PGVECTOR=$(WITH_PGVECTOR) \
		--build-arg PGVECTOR_VERSION=$(PGVECTOR_VERSION) \
		--build-arg PGVECTOR_SHA256=$(PGVECTOR_SHA256) \
		--build-arg POSTGRES_DB_EXTENSIONS_DEFAULT=$(POSTGRES_DB_EXTENSIONS_DEFAULT) \
		--build-arg ALPINE_VER=$(ALPINE_VER) \
		./

buildx-imagetools-create:
	docker buildx imagetools create -t $(REPO):$(IMAGETOOLS_TAG) \
				  $(REPO):$(TAG)-amd64 \
				  $(REPO):$(TAG)-arm64
.PHONY: buildx-imagetools-create 

test:
	cd ./tests && NAME=$(NAME) IMAGE=$(REPO):$(TAG) TEST_POSTGIS=$(WITH_POSTGIS) TEST_PGVECTOR=$(WITH_PGVECTOR) ./run.sh

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

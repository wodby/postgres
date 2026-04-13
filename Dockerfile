ARG POSTGRES_VER

FROM postgres:${POSTGRES_VER:-18}-alpine

ARG POSTGRES_VER
ARG POSTGRES_MAJOR_VER
ARG POSTGIS_VERSION
ARG POSTGIS_SHA256
ARG NPROC

ARG TARGETPLATFORM

ENV POSTGRES_VER="${POSTGRES_VER}" \
    # Major version: 10.2 => 10, 9.6.3 => 9.6
    # http://www.databasesoup.com/2016/05/changing-postgresql-version-numbering.html
    POSTGRES_MAJOR_VER="${POSTGRES_MAJOR_VER}" \
    POSTGIS_VERSION="${POSTGIS_VERSION}" \
    POSTGIS_SHA256="${POSTGIS_SHA256}" \
    POSTGRES_USER="postgres"

RUN set -ex; \
    test -n "${POSTGIS_VERSION}"; \
    test -n "${POSTGIS_SHA256}"; \
    apk add --no-cache -t .postgres-run-deps \
        ca-certificates \
        gdal \
        geos \
        json-c \
        libstdc++ \
        make \
        pcre2 \
        proj \
        protobuf-c \
        pwgen \
        sfcgal \
        tar \
        wget; \
    apk add --no-cache -t .postgres-build-deps \
        autoconf \
        automake \
        cunit-dev \
        file \
        g++ \
        gcc \
        gdal-dev \
        geos-dev \
        gettext-dev \
        git \
        json-c-dev \
        libtool \
        libxml2-dev \
        openssl \
        pcre2-dev \
        perl \
        proj-dev \
        proj-util \
        protobuf-c-dev \
        sfcgal-dev \
        ${DOCKER_PG_LLVM_DEPS}; \
    wget -O /tmp/postgis.tar.gz "https://github.com/postgis/postgis/archive/${POSTGIS_VERSION}.tar.gz"; \
    echo "${POSTGIS_SHA256} */tmp/postgis.tar.gz" | sha256sum -c -; \
    mkdir -p /usr/src/postgis; \
    tar --extract --file /tmp/postgis.tar.gz --directory /usr/src/postgis --strip-components 1; \
    rm /tmp/postgis.tar.gz; \
    cd /usr/src/postgis; \
    gettextize; \
    ./autogen.sh; \
    ./configure --enable-lto; \
    make -j"${NPROC:-$(nproc)}"; \
    make install; \
    mkdir -p /tmp/postgis-smoke; \
    chown -R postgres:postgres /tmp/postgis-smoke; \
    su postgres -c 'pg_ctl -D /tmp/postgis-smoke init'; \
    su postgres -c 'pg_ctl -D /tmp/postgis-smoke -l /tmp/postgis.log -o "-F" start'; \
    su postgres -c 'psql -c "CREATE EXTENSION IF NOT EXISTS postgis;"'; \
    su postgres -c 'psql -c "CREATE EXTENSION IF NOT EXISTS postgis_raster;"'; \
    su postgres -c 'psql -c "CREATE EXTENSION IF NOT EXISTS postgis_sfcgal;"'; \
    su postgres -c 'psql -c "CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;"'; \
    su postgres -c 'psql -c "CREATE EXTENSION IF NOT EXISTS address_standardizer;"'; \
    su postgres -c 'psql -c "CREATE EXTENSION IF NOT EXISTS address_standardizer_data_us;"'; \
    su postgres -c 'psql -c "CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;"'; \
    su postgres -c 'psql -c "CREATE EXTENSION IF NOT EXISTS postgis_topology;"'; \
    su postgres -c 'psql -tAc "SELECT PostGIS_Full_Version();"' >/tmp/postgis-version.txt; \
    su postgres -c 'pg_ctl -D /tmp/postgis-smoke --mode=immediate stop'; \
    rm -rf /tmp/postgis-smoke /tmp/postgis.log /usr/src/postgis /tmp/postgis-version.txt; \
    apk del .postgres-build-deps; \
    \
    dockerplatform=${TARGETPLATFORM:-linux/amd64};\
    gotpl_url="https://github.com/wodby/gotpl/releases/latest/download/gotpl-${dockerplatform/\//-}.tar.gz"; \
    wget -qO- "${gotpl_url}" | tar xz --no-same-owner -C /usr/local/bin

COPY bin /usr/local/bin
COPY templates /etc/gotpl/
COPY initdb.d /docker-entrypoint-initdb.d/

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["-c", "config_file=/etc/postgresql/postgresql.conf"]

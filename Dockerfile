ARG BASE_IMAGE_TAG

FROM postgres:${BASE_IMAGE_TAG}

ARG POSTGRES_VER
ARG POSTGRES_MAJOR_VER

ENV POSTGRES_VER="${POSTGRES_VER}" \
    # Major version: 10.2 => 10, 9.6.3 => 9.6
    # http://www.databasesoup.com/2016/05/changing-postgresql-version-numbering.html
    POSTGRES_MAJOR_VER="${POSTGRES_MAJOR_VER}" \
    GOTPL_VER="0.1.5" \
    POSTGRES_USER="postgres"

RUN apk add --no-cache -t .postgres-run-deps \
        ca-certificates \
        make \
        pwgen \
        tar \
        wget; \
    \
    gotpl_url="https://github.com/wodby/gotpl/releases/download/${GOTPL_VER}/gotpl-alpine-linux-amd64-${GOTPL_VER}.tar.gz"; \
    wget -qO- "${gotpl_url}" | tar xz -C /usr/local/bin

COPY bin /usr/local/bin
COPY templates /etc/gotpl/
COPY initdb.d /docker-entrypoint-initdb.d/

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["-c", "config_file=/etc/postgresql/postgresql.conf"]

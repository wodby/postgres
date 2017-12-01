ARG FROM_TAG

FROM postgres:${FROM_TAG}

ARG POSTGRES_VER

ENV POSTGRES_VER="${POSTGRES_VER}" \
    GOTPL_VER="0.1.5" \
    POSTGRES_USER="postgres"

RUN apk add --no-cache --virtual .postgres-run-deps \
        ca-certificates \
        make \
        pwgen \
        tar \
        wget && \

    wget -qO- https://github.com/wodby/gotpl/releases/download/${GOTPL_VER}/gotpl-alpine-linux-amd64-${GOTPL_VER}.tar.gz | tar xz -C /usr/local/bin

COPY actions /usr/local/bin
COPY conf/templates /etc/gotpl/
COPY initdb.d /docker-entrypoint-initdb.d/

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["-c", "config_file=/etc/postgresql/postgresql.conf"]

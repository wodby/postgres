FROM postgres:9.6-alpine

ENV GOTPL_VER 0.1.5
ENV POSTGRES_USER postgres

RUN apk add --no-cache \
        ca-certificates \
        make \
        pwgen \
        tar \
        wget && \

    wget -qO- https://github.com/wodby/gotpl/releases/download/${GOTPL_VER}/gotpl-alpine-linux-amd64-${GOTPL_VER}.tar.gz | tar xz -C /usr/local/bin

COPY actions /usr/local/bin

COPY *.tpl /etc/gotpl/
COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["-c", "config_file=/etc/postgresql/postgresql.conf"]

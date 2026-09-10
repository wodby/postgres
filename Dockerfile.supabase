ARG SUPABASE_IMAGE=supabase/postgres:17.6.1.136@sha256:f371b5f3f2ac0a05703f33d6e6134515fb2498cab708fb948a0aeb7481467c00
FROM ${SUPABASE_IMAGE}

USER root
RUN apk add --no-cache make python3 && \
    test ! -e /etc/postgresql-custom/pgsodium_root.key && \
    ln -s /var/lib/postgresql/wodby-keys/pgsodium_root.key /etc/postgresql-custom/pgsodium_root.key
COPY supabase/init-scripts/ /docker-entrypoint-initdb.d/init-scripts/
COPY supabase/migrations/ /docker-entrypoint-initdb.d/migrations/
COPY supabase/init-hook.sh /docker-entrypoint-initdb.d/zz-wodby-import.sh
COPY supabase/actions.mk /usr/local/share/wodby/supabase-actions.mk
COPY supabase/ops.py /usr/local/bin/supabase-ops
COPY supabase/entrypoint.sh /usr/local/bin/wodby-supabase-entrypoint
COPY supabase/UPSTREAM-LICENSE /usr/local/share/wodby/SUPABASE-LICENSE
RUN chmod 0755 /usr/local/bin/supabase-ops /usr/local/bin/wodby-supabase-entrypoint \
    /docker-entrypoint-initdb.d/zz-wodby-import.sh
ENV POSTGRES_MAJOR_VER=17 JWT_EXP=3600
ENTRYPOINT ["wodby-supabase-entrypoint"]
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf", "-c", "log_min_messages=warning"]

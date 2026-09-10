#!/usr/bin/env bash
set -euo pipefail
# Operational jobs dispatch before server setup and never rewrite upstream configuration.
if [[ "${1:-}" == make ]]; then
    shift
    exec make --no-print-directory -f /usr/local/share/wodby/supabase-actions.mk "$@"
fi
if [[ "${1:-}" == -* ]]; then set -- postgres "$@"; fi
if [[ "${1:-}" == postgres ]]; then
    supabase-ops prepare
fi
exec /usr/local/bin/docker-entrypoint.sh "$@"

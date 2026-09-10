#!/usr/bin/env bash
set -euo pipefail
# Runs after upstream migrations, while only the temporary Unix-socket server is listening.
export PGHOST=/var/run/postgresql PGUSER=supabase_admin PGDATABASE=postgres
supabase-ops finish-init

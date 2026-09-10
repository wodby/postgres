#!/usr/bin/env bash
set -euo pipefail
# Wodby CLI supplies the workspace; a Docker CLI container builds against the host daemon.
cd "$(dirname "$0")/.."
export IMAGE=${IMAGE:-wodby/postgres:17-supabase-test}
case "$IMAGE" in wodby/postgres:*) ;; *) echo 'IMAGE must use the wodby/postgres repository' >&2; exit 1;; esac
command -v wodby >/dev/null
config_dir=$(mktemp -d)
config="$config_dir/config.json"
workspace_container=''
cleanup() {
    rm -f "$config"
    rmdir "$config_dir"
    if [[ -n "$workspace_container" ]]; then docker rm "$workspace_container" >/dev/null; fi
}
trap cleanup EXIT
docker pull docker:29-cli >/dev/null
workspace_container=$(docker create -v "$PWD:/workspace" docker:29-cli true)
python3 - "$config" "$PWD" "$workspace_container" <<'PY'
import json,sys
with open(sys.argv[1],'w') as output:
    json.dump({'context':sys.argv[2],'dataContainer':sys.argv[3],'workingDir':'/workspace'},output)
PY
wodby ci run --ci-config-path "$config" -i docker:29-cli -u root -p . --entrypoint /bin/sh --no-cache \
    -v /var/run/docker.sock:/var/run/docker.sock -e "IMAGE=$IMAGE" -- -ec \
    'apk add --no-cache make bash python3 >/dev/null; make WITH_SUPABASE=1 TAG="${IMAGE#wodby/postgres:}" build test'

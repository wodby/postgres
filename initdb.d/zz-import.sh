# This file is intentionally not executable. The upstream PostgreSQL entrypoint
# sources it so docker_process_init_files remains available here.

if [[ -d /wodby/import ]]; then
    shopt -s nullglob
    wodby_import_files=(/wodby/import/*)
    if (( ${#wodby_import_files[@]} > 0 )); then
        docker_process_init_files "${wodby_import_files[@]}"
    fi
    unset wodby_import_files
    shopt -u nullglob
fi

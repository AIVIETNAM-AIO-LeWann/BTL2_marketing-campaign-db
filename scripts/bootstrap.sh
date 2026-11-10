#!/usr/bin/env bash
# Run on an empty database. MYSQL_CLIENT may point to mysql-docker.sh.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
client="${MYSQL_CLIENT:-mysql}"
files=(
  "$repo_root/database/01_schema.sql"
  "$repo_root/database/02_constraints.sql"
  "$repo_root/database/03_creation_workflows.sql"
  "$repo_root/database/04_seed.sql"
  "$repo_root/database/05_reports.sql"
  "$repo_root/database/06_verify.sql"
)
for file in "${files[@]}"; do
  if [[ ! -r "$file" ]]; then
    printf 'Cannot read SQL file: %s\n' "$file" >&2
    exit 1
  fi
done
# One mysql session, strict ordering, fail on SQL error. No --force or DROP.
cat "${files[@]}" | "$client" --default-character-set=utf8mb4 "$@"

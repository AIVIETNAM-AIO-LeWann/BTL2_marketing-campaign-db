#!/usr/bin/env bash
# Same client interface for bootstrap.sh and the Python test runner.
# MYSQL_PWD is inherited by the client, not written to a file or CLI argument.
set -euo pipefail
container="${MYSQL_CONTAINER:-marketing-btl2-mysql}"
exec docker exec -i -e MYSQL_PWD "$container" mysql "$@"

#!/bin/sh
set -eu
CI_ROOT="${GITHUB_WORKSPACE:-$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)}"
SOURCE_ROOT="${SOURCE_DIR:-source}"
case "$SOURCE_ROOT" in /*) ;; *) SOURCE_ROOT="$CI_ROOT/$SOURCE_ROOT" ;; esac
exec node "$SOURCE_ROOT/desktop/scripts/workflow.mjs" "$@"

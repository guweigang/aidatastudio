#!/bin/bash
set -euo pipefail
archive="$RUNNER_TEMP/libduckdb-linux-amd64.zip"
prefix="$RUNNER_TEMP/duckdb-1.5.5"
curl --fail --location https://github.com/duckdb/duckdb/releases/download/v1.5.5/libduckdb-linux-amd64.zip --output "$archive"
printf '%s  %s\n' 1fb8ce388157d84a25abe685a8a2520bf00c00321821968e4bb398fd766e7abb "$archive" | sha256sum --check
mkdir -p "$prefix"
unzip -q "$archive" -d "$prefix"
echo "LIBDUCKDB_DIR=$prefix" >> "$GITHUB_ENV"

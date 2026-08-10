#!/bin/sh

set -eu
archive="${RUNNER_TEMP}/libduckdb-osx-universal.zip"
extract_dir="${RUNNER_TEMP}/libduckdb-osx-universal"
curl --fail --location --retry 3 \
  "https://github.com/duckdb/duckdb/releases/download/${DUCKDB_VERSION}/libduckdb-osx-universal.zip" \
  --output "${archive}"
rm -rf "${extract_dir}"
mkdir -p "${extract_dir}"
ditto -x -k "${archive}" "${extract_dir}"
duckdb_library="$(find "${extract_dir}" -type f -name 'libduckdb.dylib' -print -quit)"
if [ -z "${duckdb_library}" ]; then
  echo "libduckdb.dylib was not found in the DuckDB ${DUCKDB_VERSION} archive" >&2
  exit 1
fi
lipo -info "${duckdb_library}"
mkdir -p "${SOURCE_DIR}/backend/runtime/libs"
cp "${duckdb_library}" "${SOURCE_DIR}/backend/runtime/libs/libduckdb.dylib"
echo "LIBDUCKDB_DIR=${GITHUB_WORKSPACE}/${SOURCE_DIR}/backend/runtime/libs" >> "${GITHUB_ENV}"

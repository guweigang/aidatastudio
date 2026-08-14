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

case "$(uname -m)" in
  arm64)
    duckdb_arch="arm64"
    ;;
  x86_64)
    duckdb_arch="x86_64"
    ;;
  *)
    echo "unsupported macOS runner architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

thin_duckdb_library="${extract_dir}/libduckdb-${duckdb_arch}.dylib"
lipo "${duckdb_library}" -thin "${duckdb_arch}" -output "${thin_duckdb_library}"
lipo "${thin_duckdb_library}" -verify_arch "${duckdb_arch}"
lipo -info "${thin_duckdb_library}"
mkdir -p "${SOURCE_DIR}/backend/runtime/libs"
cp "${thin_duckdb_library}" "${SOURCE_DIR}/backend/runtime/libs/libduckdb.dylib"
echo "LIBDUCKDB_DIR=${GITHUB_WORKSPACE}/${SOURCE_DIR}/backend/runtime/libs" >> "${GITHUB_ENV}"

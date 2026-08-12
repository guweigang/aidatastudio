#!/bin/sh

set -eu

version="${MONGO_C_DRIVER_VERSION:?MONGO_C_DRIVER_VERSION is required}"
archive="${RUNNER_TEMP}/mongo-c-driver-${version}.tar.gz"
source_dir="${RUNNER_TEMP}/mongo-c-driver-${version}"
build_dir="${RUNNER_TEMP}/mongo-c-driver-${version}-build"
prefix="${RUNNER_TEMP}/mongo-c-driver-${version}-install"

curl --fail --location --retry 3 \
  "https://github.com/mongodb/mongo-c-driver/releases/download/${version}/mongo-c-driver-${version}.tar.gz" \
  --output "${archive}"
rm -rf "${source_dir}" "${build_dir}" "${prefix}"
tar -xzf "${archive}" -C "${RUNNER_TEMP}"

cmake -S "${source_dir}" -B "${build_dir}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${prefix}" \
  -DENABLE_MONGOC=ON \
  -DENABLE_TESTS=OFF \
  -DENABLE_EXAMPLES=OFF \
  -DENABLE_MAN_PAGES=OFF \
  -DENABLE_HTML_DOCS=OFF
cmake --build "${build_dir}" --parallel 2
cmake --install "${build_dir}"

pkg_config_dir="$(find "${prefix}" -type f -name mongoc2.pc -exec dirname {} \; -quit)"
library_dir="$(find "${prefix}" -type f -name 'libmongoc2.so*' -exec dirname {} \; -quit)"
if [ -z "${pkg_config_dir}" ] || [ -z "${library_dir}" ]; then
  echo "mongo-c-driver ${version} did not install mongoc2 pkg-config metadata and runtime library" >&2
  exit 1
fi

{
  echo "MONGO_C_DRIVER_ROOT=${prefix}"
  echo "PKG_CONFIG_PATH=${pkg_config_dir}:${PKG_CONFIG_PATH:-}"
  echo "LIBRARY_PATH=${library_dir}:${LIBRARY_PATH:-}"
  echo "LD_LIBRARY_PATH=${library_dir}:${LD_LIBRARY_PATH:-}"
} >> "${GITHUB_ENV}"

PKG_CONFIG_PATH="${pkg_config_dir}:${PKG_CONFIG_PATH:-}" pkg-config --modversion mongoc2

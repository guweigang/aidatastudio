#!/bin/sh

set -eu
# Keep the runner image's native dependency snapshot. Updating Homebrew here
# upgrades unrelated tools and can turn an Intel build into hours of source builds.
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_UPGRADE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
core_tap="$(brew --repository homebrew/core 2>/dev/null || true)"
if [ -n "$core_tap" ] && [ -d "$core_tap" ]; then
  # Runner images may carry compatible formula revisions in their local tap.
  export HOMEBREW_NO_INSTALL_FROM_API=1
fi
brew install bdw-gc libpq mongo-c-driver mysql-client openssl@3 pkg-config sqlite uv
mysql_prefix="$(brew --prefix mysql-client)"
libpq_prefix="$(brew --prefix libpq)"
mongo_prefix="$(brew --prefix mongo-c-driver)"
openssl_prefix="$(brew --prefix openssl@3)"
gc_prefix="$(brew --prefix bdw-gc)"
sqlite_prefix="$(brew --prefix sqlite)"
{
  echo "${mysql_prefix}/bin"
  echo "${libpq_prefix}/bin"
  echo "${mongo_prefix}/bin"
  echo "${openssl_prefix}/bin"
  echo "${sqlite_prefix}/bin"
} >> "${GITHUB_PATH}"
{
  echo "PKG_CONFIG_PATH=${mongo_prefix}/lib/pkgconfig:${mysql_prefix}/lib/pkgconfig:${libpq_prefix}/lib/pkgconfig:${openssl_prefix}/lib/pkgconfig:${gc_prefix}/lib/pkgconfig:${sqlite_prefix}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
  echo "CPPFLAGS=-I${mysql_prefix}/include/mysql -I${libpq_prefix}/include -I${openssl_prefix}/include -I${gc_prefix}/include -I${sqlite_prefix}/include ${CPPFLAGS:-}"
  echo "LDFLAGS=-L${mongo_prefix}/lib -L${mysql_prefix}/lib -L${libpq_prefix}/lib -L${openssl_prefix}/lib -L${gc_prefix}/lib -L${sqlite_prefix}/lib ${LDFLAGS:-}"
  echo "MONGO_C_DRIVER_ROOT=${mongo_prefix}"
  echo "OPENSSL_ROOT_DIR=${openssl_prefix}"
  echo "POSTGRES_ROOT=${libpq_prefix}"
} >> "${GITHUB_ENV}"
PKG_CONFIG_PATH="${mongo_prefix}/lib/pkgconfig:${PKG_CONFIG_PATH:-}" pkg-config --modversion mongoc2

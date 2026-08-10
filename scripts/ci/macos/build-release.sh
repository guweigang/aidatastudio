#!/bin/sh

set -eu
case "${RELEASE_MODE}:${TARGET_MODE}" in
  unsigned:host|unsigned:apple-silicon|unsigned:intel)
    npm --prefix desktop run release:macos
    ;;
  unsigned:universal)
    npm --prefix desktop run release:macos:universal
    ;;
  signed:host|signed:apple-silicon|signed:intel)
    npm --prefix desktop run release:macos:signed
    ;;
  signed-skip-stapling:host|signed-skip-stapling:apple-silicon|signed-skip-stapling:intel)
    npm --prefix desktop run release:macos:signed:skip-stapling
    ;;
  *)
    echo "unsupported release/target combination: ${RELEASE_MODE}:${TARGET_MODE}" >&2
    exit 1
    ;;
esac

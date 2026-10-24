#!/bin/sh
set -eu
set -- release
case "${RELEASE_MODE:-unsigned}" in
  unsigned) set -- "$@" --sign adhoc ;;
  signed) set -- "$@" --sign distribution ;;
  signed-skip-stapling) set -- "$@" --sign distribution --skip-stapling ;;
  *) echo "unsupported release mode: $RELEASE_MODE" >&2; exit 1 ;;
esac
case "${TARGET_MODE:-host}" in
  host|apple-silicon|intel) ;;
  universal) set -- "$@" --target universal ;;
  *) echo "unsupported target mode: $TARGET_MODE" >&2; exit 1 ;;
esac
exec sh "$(dirname -- "$0")/run-source-workflow.sh" "$@"

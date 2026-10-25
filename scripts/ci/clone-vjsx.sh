#!/bin/sh
set -eu
: "${VJSX_REPO:?VJSX_REPO required}"
: "${VJSX_DIR:?VJSX_DIR required}"
VJSX_REF="${VJSX_REF:-main}"
git init "$VJSX_DIR"
git -C "$VJSX_DIR" remote add origin "$VJSX_REPO"
git -C "$VJSX_DIR" fetch --depth 1 origin "$VJSX_REF"
git -C "$VJSX_DIR" checkout --detach FETCH_HEAD
printf 'vjsx source ref=%s\n' "$VJSX_REF"
git -C "$VJSX_DIR" log -1 --format='vjsx source commit=%H'

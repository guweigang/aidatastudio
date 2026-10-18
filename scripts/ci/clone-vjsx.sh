#!/bin/sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/v-toolchain.env"
: "${VJSX_REPO:?VJSX_REPO required}"
: "${VJSX_DIR:?VJSX_DIR required}"
: "${VJSX_COMMIT:?VJSX_COMMIT required}"
git init "$VJSX_DIR"
git -C "$VJSX_DIR" remote add origin "$VJSX_REPO"
git -C "$VJSX_DIR" fetch --depth 1 origin "$VJSX_COMMIT"
git -C "$VJSX_DIR" checkout --detach "$VJSX_COMMIT"
test "$(git -C "$VJSX_DIR" rev-parse HEAD)" = "$VJSX_COMMIT"

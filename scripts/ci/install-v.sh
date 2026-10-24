#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/v-toolchain.env"

: "${RUNNER_TEMP:?RUNNER_TEMP is required}"
: "${GITHUB_PATH:?GITHUB_PATH is required}"
: "${V_REPO:?V_REPO is required}"
: "${V_COMMIT:?V_COMMIT is required}"

install_root="${RUNNER_TEMP}/v"

git init "$install_root"
git -C "$install_root" remote add origin "$V_REPO"
git -C "$install_root" fetch --depth 1 origin "$V_COMMIT"
git -C "$install_root" checkout --detach FETCH_HEAD
actual_commit="$(git -C "$install_root" rev-parse HEAD)"
if [ "$actual_commit" != "$V_COMMIT" ]; then
  echo "unexpected V commit: $actual_commit; expected $V_COMMIT" >&2
  exit 1
fi

case "$(uname -s)" in
  Linux)
    if ! make -C "$install_root" CC=cc; then
      echo "V make failed after bootstrap; checking whether the compiler binary was produced" >&2
      test -x "$install_root/v"
    fi
    ;;
  Darwin)
    if ! make -C "$install_root"; then
      echo "V make failed after bootstrap; checking whether the compiler binary was produced" >&2
      test -x "$install_root/v"
    fi
    ;;
  *)
    echo "unsupported platform for install-v.sh: $(uname -s)" >&2
    exit 1
    ;;
esac

verified_commit="$(git -C "$install_root" rev-parse HEAD)"
if [ "$verified_commit" != "$V_COMMIT" ]; then
  echo "V checkout changed during build: $verified_commit; expected $V_COMMIT" >&2
  exit 1
fi

"$install_root/v" version
printf 'V commit: %s\n' "$verified_commit"
printf '%s\n' "$install_root" >> "$GITHUB_PATH"

#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/v-toolchain.env"

: "${RUNNER_TEMP:?RUNNER_TEMP is required}"
: "${GITHUB_PATH:?GITHUB_PATH is required}"
: "${V_REPO:?V_REPO is required}"
: "${V_COMMIT:?V_COMMIT is required}"
: "${VC_REPO:?VC_REPO is required}"
: "${VC_COMMIT:?VC_COMMIT is required}"

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

bootstrap_root="$install_root/vc"
git init "$bootstrap_root"
git -C "$bootstrap_root" fetch --depth 1 "$VC_REPO" "$VC_COMMIT"
git -C "$bootstrap_root" checkout --detach FETCH_HEAD
actual_vc_commit="$(git -C "$bootstrap_root" rev-parse HEAD)"
if [ "$actual_vc_commit" != "$VC_COMMIT" ]; then
  echo "unexpected vc commit: $actual_vc_commit; expected $VC_COMMIT" >&2
  exit 1
fi
printf 'V bootstrap vc commit: %s\n' "$actual_vc_commit"

case "$(uname -s)" in
  Linux) set -- CC=cc ;;
  Darwin) set -- ;;
  *)
    echo "unsupported platform for install-v.sh: $(uname -s)" >&2
    exit 1
    ;;
esac

# Refresh the platform C toolchain separately; local mode prevents a vc pull.
make -C "$install_root" "$@" latest_tcc latest_legacy
make -C "$install_root" "$@" local=1

verified_commit="$(git -C "$install_root" rev-parse HEAD)"
if [ "$verified_commit" != "$V_COMMIT" ]; then
  echo "V checkout changed during build: $verified_commit; expected $V_COMMIT" >&2
  exit 1
fi

verified_vc_commit="$(git -C "$bootstrap_root" rev-parse HEAD)"
if [ "$verified_vc_commit" != "$VC_COMMIT" ]; then
  echo "vc checkout changed during build: $verified_vc_commit; expected $VC_COMMIT" >&2
  exit 1
fi
"$install_root/v" version
printf 'V commit: %s\n' "$verified_commit"
printf '%s\n' "$install_root" >> "$GITHUB_PATH"

#!/bin/sh

set -eu
git clone --depth 1 https://github.com/vlang/v.git "${RUNNER_TEMP}/v"
if ! make -C "${RUNNER_TEMP}/v"; then
  echo "V make failed after bootstrap; checking whether the compiler binary was produced" >&2
  test -x "${RUNNER_TEMP}/v/v"
fi
"${RUNNER_TEMP}/v/v" -version
echo "${RUNNER_TEMP}/v" >> "${GITHUB_PATH}"

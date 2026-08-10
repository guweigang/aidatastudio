#!/bin/sh

set -eu
xcodebuild -version
sdk_version="$(xcrun --sdk macosx --show-sdk-version)"
echo "macOS SDK ${sdk_version}"
case "${sdk_version}" in
  26.*) ;;
  *) echo "macOS 26 SDK required, got ${sdk_version}" >&2; exit 1 ;;
esac

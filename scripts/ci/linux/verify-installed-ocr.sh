#!/bin/bash
set -euo pipefail
package="$(find source/desktop/src-tauri/target/release/bundle/deb -name '*.deb' -type f)"
test -n "$package"
name="$(dpkg-deb -f "$package" Package)"
sudo apt-get install -y "$PWD/$package"
dpkg-query -L "$name" > "$RUNNER_TEMP/attachment-ocr-evidence/installed-files.txt"
python3 scripts/ci/linux/verify-installed-ocr.py

#!/bin/bash
set -euo pipefail
build="${RUNNER_TEMP:?}/attachment-ocr-build"
evidence="${RUNNER_TEMP}/attachment-ocr-evidence"
mkdir -p "$build" "$evidence"
python3 desktop/scripts/fetch-attachment-pdfium.py --target linux-x64 --output "$build/pdfium"
python3 desktop/scripts/fetch-attachment-ocr-models.py --output "$build/tessdata"
cargo build --release --locked --features acceptance-probe --manifest-path desktop/native/attachment-ocr/Cargo.toml
python3 desktop/scripts/prepare-attachment-ocr.py --prefix /usr --pdfium "$build/pdfium" --worker desktop/native/attachment-ocr/target/release/vtable-attachment-ocr --tessdata "$build/tessdata" --output backend/runtime/attachment-ocr
python3 desktop/scripts/test-attachment-ocr.py --runtime backend/runtime/attachment-ocr --normalizer desktop/native/attachment-ocr/target/release/attachment-normalization-probe --output "$evidence/native-acceptance.json"

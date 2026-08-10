#!/bin/sh

set -eu
npm --prefix desktop run check
npm --prefix desktop run sidecar:prepare
npm --prefix desktop run build
cargo check --manifest-path desktop/src-tauri/Cargo.toml

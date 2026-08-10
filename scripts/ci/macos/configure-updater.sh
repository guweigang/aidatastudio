#!/bin/sh

set -eu
if [ -z "${TAURI_SIGNING_PRIVATE_KEY}" ]; then
  echo "TAURI_SIGNING_PRIVATE_KEY secret is required to publish updater artifacts" >&2
  exit 1
fi
node -e '
  const fs = require("fs");
  const pubkey = process.env.TAURI_UPDATER_PUBLIC_KEY_SECRET || process.env.TAURI_UPDATER_PUBLIC_KEY_VAR;
  if (!pubkey) {
    console.error("TAURI_UPDATER_PUBLIC_KEY repository variable or secret is required");
    process.exit(1);
  }
  const config = {
    bundle: { createUpdaterArtifacts: true },
    plugins: {
      updater: {
        pubkey,
        endpoints: [process.env.TAURI_UPDATER_ENDPOINT],
        windows: { installMode: "passive" }
      }
    }
  };
  fs.writeFileSync(`${process.env.RUNNER_TEMP}/tauri-updater.conf.json`, JSON.stringify(config, null, 2));
'
echo "TAURI_BUILD_CONFIG=${RUNNER_TEMP}/tauri-updater.conf.json" >> "${GITHUB_ENV}"

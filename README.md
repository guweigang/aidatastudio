# AIData Studio CI

This repository intentionally contains CI and distribution wiring only. Source
code is fetched from CNB during a manually triggered GitHub Actions run.

## Manual Build

Open **Actions -> Build AIData Studio -> Run workflow**, then choose:

- `source_ref`: CNB branch, tag, or commit to build.
- `release_mode`: `unsigned`, `signed`, or `signed-skip-stapling`.
- `target_mode`: `host` or `universal`.
- `publish_github_release`: upload the DMG/checksums to a GitHub Release.

## Repository Variables

- `CNB_SOURCE_REPO`: source repository URL. Defaults to
  `https://cnb.cool/bullsoft/vtable.git`.
- `VJSX_REPO`: vjsx repository URL. Defaults to
  `https://github.com/guweigang/vjsx.git`.
- `VTABLE_SIDECAR_V_FLAGS`: V compile flags. Defaults to
  `-d vjsx_mysql -d use_openssl`.

## Repository Secrets

- `CNB_SSH_PRIVATE_KEY`: optional SSH private key for private CNB repositories.
- Apple signing/notarization secrets are optional and only needed for signed
  builds: `APPLE_SIGNING_IDENTITY`, `APPLE_CERTIFICATE`,
  `APPLE_CERTIFICATE_PASSWORD`, `APPLE_ID`, `APPLE_PASSWORD`, `APPLE_TEAM_ID`,
  `APPLE_API_KEY`, `APPLE_API_ISSUER`, `APPLE_API_KEY_PATH`, and
  `APPLE_PROVIDER_SHORT_NAME`.

Unsigned host builds should work without Apple signing secrets.

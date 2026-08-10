#!/bin/sh

set -eu
version="$(node -e "const fs=require('fs'); const p='dist/macos/release.json'; const d=JSON.parse(fs.readFileSync(p,'utf8')); process.stdout.write(d.version)")"
artifact="$(node -e "const fs=require('fs'); const p='dist/macos/release.json'; const d=JSON.parse(fs.readFileSync(p,'utf8')); process.stdout.write(d.artifact)")"
arch="$(node -e "const fs=require('fs'); const p='dist/macos/release.json'; const d=JSON.parse(fs.readFileSync(p,'utf8')); process.stdout.write(d.arch)")"
echo "version=${version}" >> "${GITHUB_OUTPUT}"
echo "artifact=${artifact}" >> "${GITHUB_OUTPUT}"
echo "arch=${arch}" >> "${GITHUB_OUTPUT}"
echo "tag=v${version}" >> "${GITHUB_OUTPUT}"

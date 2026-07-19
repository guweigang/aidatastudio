#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const inputDir = process.argv[2];
const repo = process.env.GITHUB_REPOSITORY || "guweigang/aidatastudio";

if (!inputDir) {
  console.error("usage: generate-tauri-latest-json.mjs <artifact-dir>");
  process.exit(2);
}

function walk(dir) {
  const entries = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      entries.push(...walk(fullPath));
    } else {
      entries.push(fullPath);
    }
  }
  return entries;
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function releaseAssetUrl(version, fileName) {
  return `https://github.com/${repo}/releases/download/v${version}/${encodeURIComponent(fileName)}`;
}

function platformKeys(metadata) {
  if (metadata.platform === "windows") {
    return ["windows-x86_64"];
  }

  if (metadata.platform === "macos") {
    if (metadata.arch === "intel") {
      return ["darwin-x86_64"];
    }
    if (metadata.arch === "universal") {
      return ["darwin-aarch64", "darwin-x86_64"];
    }
    return ["darwin-aarch64"];
  }

  return [];
}

function findWindowsUpdaterArtifact(files) {
  const packages = files
    .filter((file) => [".exe", ".msi", ".zip"].includes(path.extname(file).toLowerCase()))
    .sort((a, b) => {
      const score = (file) => (file.endsWith(".exe") ? 0 : file.endsWith(".msi") ? 1 : 2);
      return score(a) - score(b) || path.basename(a).localeCompare(path.basename(b));
    });

  for (const file of packages) {
    const signature = `${file}.sig`;
    if (fs.existsSync(signature)) {
      return { artifact: file, signature };
    }
  }

  return null;
}

const files = walk(inputDir);
const metadataFiles = files.filter((file) => path.basename(file) === "release.json");
if (metadataFiles.length === 0) {
  console.error(`no release.json files found under ${inputDir}`);
  process.exit(1);
}

const platforms = {};
let version = "";
let notes = "";

for (const metadataFile of metadataFiles) {
  const metadata = readJson(metadataFile);
  version ||= metadata.version;
  if (metadata.version !== version) {
    console.error(`mixed release versions are not supported: ${version} and ${metadata.version}`);
    process.exit(1);
  }

  const dir = path.dirname(metadataFile);
  const keys = platformKeys(metadata);
  if (keys.length === 0) {
    continue;
  }

  let artifactPath = "";
  let signaturePath = "";

  if (metadata.updaterArtifact && metadata.updaterSignature) {
    artifactPath = path.join(dir, metadata.updaterArtifact);
    signaturePath = path.join(dir, metadata.updaterSignature);
  } else if (metadata.platform === "windows") {
    const windowsArtifact = findWindowsUpdaterArtifact(files.filter((file) => path.dirname(file) === dir));
    if (windowsArtifact) {
      artifactPath = windowsArtifact.artifact;
      signaturePath = windowsArtifact.signature;
    }
  }

  if (!artifactPath || !signaturePath || !fs.existsSync(artifactPath) || !fs.existsSync(signaturePath)) {
    console.error(`missing updater artifact or signature for ${metadata.platform} ${metadata.arch || ""}`);
    process.exit(1);
  }

  const signature = fs.readFileSync(signaturePath, "utf8").trim();
  for (const key of keys) {
    platforms[key] = {
      signature,
      url: releaseAssetUrl(version, path.basename(artifactPath)),
    };
  }

  const notesFile = path.join(dir, "RELEASE_NOTES.md");
  if (!notes && fs.existsSync(notesFile)) {
    notes = fs.readFileSync(notesFile, "utf8").trim();
  }
}

if (Object.keys(platforms).length === 0) {
  console.error("no updater platforms were generated");
  process.exit(1);
}

const latest = {
  version,
  notes,
  pub_date: new Date().toISOString(),
  platforms,
};

fs.writeFileSync("latest.json", `${JSON.stringify(latest, null, 2)}\n`);
process.stdout.write(version);

import { appendFile } from "node:fs/promises";

const sourceRef = process.env.SOURCE_REF ?? "";
const outputPath = process.env.GITHUB_OUTPUT;
const value = sourceRef.replace(/[\\/:*?"<>|\r\n]/g, "-");

if (!value) {
  throw new Error("SOURCE_REF must produce a non-empty artifact name component");
}
if (!outputPath) {
  throw new Error("GITHUB_OUTPUT is not set");
}

await appendFile(outputPath, `value=${value}\n`);

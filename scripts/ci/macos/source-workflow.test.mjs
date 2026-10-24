import assert from 'node:assert/strict';
import test from 'node:test';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
const scripts = dirname(fileURLToPath(import.meta.url));
function fixture(check) {
  const root = mkdtempSync(join(tmpdir(), 'ci source workflow '));
  const source = join(root, 'source with spaces');
  mkdirSync(join(source, 'desktop/scripts'), { recursive: true });
  writeFileSync(join(source, 'desktop/scripts/workflow.mjs'), 'import {writeFileSync} from "node:fs";writeFileSync(process.env.CI_TRACE,JSON.stringify(process.argv.slice(2)));');
  writeFileSync(join(source, 'rust-toolchain.toml'), '[toolchain]\nchannel = "1.88.0"\ncomponents = ["rustfmt", "llvm-tools-preview"]\n');
  const env = { ...process.env, GITHUB_WORKSPACE: root, SOURCE_DIR: 'source with spaces', CI_TRACE: join(root, 'trace'), GITHUB_OUTPUT: join(root, 'outputs') };
  const run = (script, overrides = {}, cwd = tmpdir()) => spawnSync(script.endsWith('.mjs') ? process.execPath : 'sh', [join(scripts, script)], { cwd, env: { ...env, ...overrides }, encoding: 'utf8' });
  try { check({ root, source, env, run, trace: () => JSON.parse(readFileSync(env.CI_TRACE, 'utf8')) }); }
  finally { rmSync(root, { recursive: true, force: true }); }
}
test('release modes and architecture selectors only forward standard workflow arguments', () => fixture(({ run, trace }) => {
  for (const [mode, flags] of [['unsigned', ['--sign', 'adhoc']], ['signed', ['--sign', 'distribution']], ['signed-skip-stapling', ['--sign', 'distribution', '--skip-stapling']]]) {
    for (const [target, extra] of [['host', []], ['apple-silicon', []], ['intel', []], ['universal', ['--target', 'universal']]]) {
      const result = run('build-release.sh', { RELEASE_MODE: mode, TARGET_MODE: target });
      assert.equal(result.status, 0, result.stderr);
      assert.deepEqual(trace(), ['release', ...flags, ...extra]);
    }
  }
}));
test('precheck does not prepare sidecar, build frontend or invoke ambient Cargo', () => fixture(({ run, trace }) => {
  const result = run('check-build-inputs.sh');
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(trace(), ['check', 'frontend']);
}));
test('unknown modes fail before calling the source workflow', () => fixture(({ run, env }) => {
  for (const overrides of [{ RELEASE_MODE: 'bad' }, { TARGET_MODE: 'bad' }]) {
    const result = run('build-release.sh', overrides);
    assert.notEqual(result.status, 0);
    assert.equal(existsSync(env.CI_TRACE), false);
  }
}));
test('source selection is independent of caller cwd and accepts an explicit absolute checkout', () => fixture(({ run, trace, root, source }) => {
  for (const cwd of [root, source, tmpdir()]) {
    const result = run('check-build-inputs.sh', { SOURCE_DIR: source }, cwd);
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(trace(), ['check', 'frontend']);
  }
}));
test('Rust channel and components come from the selected source rather than a CI version constant', () => fixture(({ run, root, source }) => {
  mkdirSync(join(root, 'source'));
  writeFileSync(join(root, 'source/rust-toolchain.toml'), readFileSync(join(source, 'rust-toolchain.toml')));
  for (const SOURCE_DIR of ['source with spaces', '']) {
    writeFileSync(join(root, 'outputs'), '');
    const result = run('read-rust-toolchain.mjs', { SOURCE_DIR });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(readFileSync(join(root, 'outputs'), 'utf8').split('\n'), ['toolchain=1.88.0', 'components=rustfmt,llvm-tools-preview', '']);
  }
}));

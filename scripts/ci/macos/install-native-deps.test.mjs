import assert from 'node:assert/strict';
import test from 'node:test';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
const scripts = dirname(fileURLToPath(import.meta.url));

function fixture(localTap, failInstall = false) {
  const root = mkdtempSync(join(tmpdir(), 'native deps snapshot '));
  const bin = join(root, 'bin');
  const tap = join(root, 'homebrew-core');
  mkdirSync(bin);
  if (localTap) mkdirSync(tap);
  const trace = join(root, 'trace');
  const probe = join(root, 'brew.mjs');
  writeFileSync(probe, String.raw`import {appendFileSync} from 'node:fs';
const args=process.argv.slice(2);
appendFileSync(process.env.TRACE,JSON.stringify({args,env:Object.fromEntries(Object.entries(process.env).filter(([key])=>key.startsWith('HOMEBREW_')))})+'\n');
if(args[0]==='--repository') console.log(process.env.TAP);
else if(args[0]==='--prefix') console.log(process.env.PREFIX+'/'+args[1]);
else if(args[0]==='install') process.exit(process.env.FAIL_INSTALL==='1'?9:0);
else throw Error('unexpected brew command '+args.join(' '));
`);
  const quote = value => "'" + value.replaceAll("'", "'\\''") + "'";
  writeFileSync(join(bin, 'brew'), '#!/bin/sh\nexec '+quote(process.execPath)+' '+quote(probe)+' "$@"\n', { mode: 0o755 });
  writeFileSync(join(bin, 'pkg-config'), '#!/bin/sh\n[ "$1" = --modversion ] && [ "$2" = mongoc2 ]\n', { mode: 0o755 });
  const paths = join(root, 'paths');
  const output = join(root, 'env');
  writeFileSync(paths, ''); writeFileSync(output, '');
  const env = { ...process.env, PATH: bin+':'+process.env.PATH, TRACE: trace, TAP: tap, PREFIX: root, FAIL_INSTALL: failInstall?'1':'0', GITHUB_PATH: paths, GITHUB_ENV: output };
  for (const key of ['HOMEBREW_NO_AUTO_UPDATE','HOMEBREW_NO_INSTALL_UPGRADE','HOMEBREW_NO_INSTALL_FROM_API']) delete env[key];
  try {
    const result = spawnSync('sh', [join(scripts, 'install-native-deps.sh')], { env, cwd: tmpdir(), encoding: 'utf8' });
    return { result, calls: readFileSync(trace, 'utf8').trim().split('\n').map(JSON.parse), output: readFileSync(output, 'utf8'), paths: readFileSync(paths, 'utf8'), root };
  } finally { rmSync(root, { recursive: true, force: true }); }
}

test('native dependency install preserves runner snapshot and exports all required library paths', () => {
  for (const localTap of [true, false]) {
    const { result, calls, output, paths, root } = fixture(localTap);
    assert.equal(result.status, 0, result.stderr);
    const installs = calls.filter(call => call.args[0] === 'install');
    assert.equal(installs.length, 1);
    assert.deepEqual(installs[0].args.slice(1), ['bdw-gc','libpq','mongo-c-driver','mysql-client','openssl@3','pkg-config','sqlite','uv']);
    assert.equal(installs[0].env.HOMEBREW_NO_AUTO_UPDATE, '1');
    assert.equal(installs[0].env.HOMEBREW_NO_INSTALL_UPGRADE, '1');
    assert.equal(installs[0].env.HOMEBREW_NO_INSTALL_FROM_API, localTap?'1':undefined);
    assert.equal(calls.some(call => ['update','upgrade'].includes(call.args[0])), false);
    assert.ok(output.includes('MONGO_C_DRIVER_ROOT='+root+'/mongo-c-driver'));
    assert.ok(output.includes('OPENSSL_ROOT_DIR='+root+'/openssl@3'));
    assert.ok(output.includes('POSTGRES_ROOT='+root+'/libpq'));
    assert.ok(paths.includes(root+'/mysql-client/bin'));
  }
});

test('failed dependency install fails before exporting unusable native paths', () => {
  const { result, output, paths } = fixture(true, true);
  assert.equal(result.status, 9, result.stderr);
  assert.equal(output, '');
  assert.equal(paths, '');
});

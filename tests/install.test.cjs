const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const pluginId = 'io.github.hussainanjar.precious-metals';
const legacyId = 'local.precious-metals';
const fixture = {
  bar: { layout: { left: [], center: [{ id: legacyId, settings: { token: 'test-private-value' } }], right: [] } },
  disabledPlugins: [legacyId, 'other.plugin'],
  unrelated: { preserved: true }
};

function setup(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'precious-metals-install-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const config = path.join(root, 'config', 'omarchy');
  const bin = path.join(root, 'bin');
  fs.mkdirSync(path.join(config, 'plugins', legacyId), { recursive: true });
  fs.mkdirSync(bin);
  // Only shell discovery/enable and validation are stubbed; the real installer,
  // jq, file copies and migration run against the isolated configuration.
  fs.writeFileSync(path.join(bin, 'omarchy'), `#!/bin/bash
case "$1 $2" in
  'plugin validate'|'plugin enable') exit 0 ;;
  'plugin list') printf '%s\\n' '[{"id":"${pluginId}"}]' ;;
  *) exit 1 ;;
esac
`, { mode: 0o755 });
  fs.writeFileSync(path.join(bin, 'omarchy-shell'), '#!/bin/bash\nexit 0\n', { mode: 0o755 });
  return { config, run: () => spawnSync('bash', [path.join(__dirname, '..', 'install.sh')], {
    env: { ...process.env, XDG_CONFIG_HOME: path.dirname(config), PATH: `${bin}:${process.env.PATH}` },
    encoding: 'utf8'
  }) };
}

for (const [mode, symlink] of [[0o600, false], [0o640, false], [0o600, true]]) {
  test(`migration preserves metadata and private backups (${mode.toString(8)}, symlink=${symlink})`, t => {
    const { config, run } = setup(t);
    const shell = path.join(config, 'shell.json');
    const target = symlink ? path.join(config, 'actual-shell.json') : shell;
    fs.writeFileSync(target, JSON.stringify(fixture), { mode });
    if (symlink) fs.symlinkSync('actual-shell.json', shell);
    const before = fs.statSync(shell);
    const result = run();
    assert.equal(result.status, 0, result.stderr);
    const after = fs.statSync(shell);
    for (const field of ['mode', 'uid', 'gid', 'ino']) assert.equal(after[field], before[field], field);
    if (symlink) assert.equal(fs.readlinkSync(shell), 'actual-shell.json');
    const expected = structuredClone(fixture);
    expected.bar.layout.center[0].id = pluginId;
    expected.disabledPlugins[0] = pluginId;
    assert.deepEqual(JSON.parse(fs.readFileSync(shell, 'utf8')), expected);
    const backups = path.join(config, 'plugin-backups');
    const backup = path.join(backups, fs.readdirSync(backups)[0]);
    for (const file of [backup, path.join(backup, 'migrated-shell.json')]) {
      assert.equal(fs.statSync(file).mode & 0o077, 0, `${file} must be private`);
    }
    assert.deepEqual(JSON.parse(fs.readFileSync(path.join(backup, 'shell.json'), 'utf8')), fixture);
    assert.ok(fs.existsSync(path.join(backup, 'legacy-plugin')));
  });
}

test('failed JSON migration leaves the existing configuration unchanged', t => {
  const { config, run } = setup(t);
  const shell = path.join(config, 'shell.json');
  fs.writeFileSync(shell, '{invalid', { mode: 0o600 });
  const before = fs.statSync(shell);
  assert.notEqual(run().status, 0);
  assert.equal(fs.readFileSync(shell, 'utf8'), '{invalid');
  assert.equal(fs.statSync(shell).mode, before.mode);
  assert.equal(fs.statSync(shell).ino, before.ino);
});

test('migration preserves an existing configuration ACL', t => {
  if (spawnSync('setfacl', ['--version']).status !== 0) {
    t.skip('setfacl is unavailable');
    return;
  }
  const { config, run } = setup(t);
  const shell = path.join(config, 'shell.json');
  fs.writeFileSync(shell, JSON.stringify(fixture), { mode: 0o600 });
  // Use the current UID, which is also valid inside restricted user namespaces.
  const acl = spawnSync('setfacl', ['-m', `u:${process.getuid()}:r--`, shell], { encoding: 'utf8' });
  if (acl.status !== 0 && /Invalid argument|Operation not supported/.test(acl.stderr)) {
    t.skip('temporary filesystem does not support ACLs');
    return;
  }
  assert.equal(acl.status, 0, acl.stderr);
  const before = spawnSync('getfacl', ['-cp', shell], { encoding: 'utf8' });
  assert.equal(before.status, 0, before.stderr);
  const result = run();
  assert.equal(result.status, 0, result.stderr);
  const after = spawnSync('getfacl', ['-cp', shell], { encoding: 'utf8' });
  assert.equal(after.status, 0, after.stderr);
  assert.equal(after.stdout, before.stdout);
});

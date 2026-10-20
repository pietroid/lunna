// Classifies every commit that touched the app: would Shorebird have shipped
// it as a patch (Dart only), or did it need a store release (native code,
// plugins, assets Shorebird does not patch, or the Flutter version)?
// Run from the topic folder: node code/patchable.mjs > data/patchable.csv
import { execSync } from 'node:child_process';

const git = (args) =>
  execSync(`git ${args}`, { encoding: 'utf8', maxBuffer: 1 << 28 });
const root = git('rev-parse --show-toplevel').trim();

// Native or build-level: needs `shorebird release`.
const native = [
  /^app\/(ios|android|macos)\//,
  /^app\/packages\/[^/]+\/(ios|android)\//,
  /^app\/brands\//,                       // launcher icons, splash
  /^app\/flutter_(launcher_icons|native_splash)-/,
  // Flutter assets (images, fonts, SVGs): Shorebird does not patch them
  // yet, so new Dart that needs them must wait for a release.
  /^app\/(assets|packages\/[^/]+\/assets)\//,
];
// Dart code and Dart-side assets: a patch.
const dart = [/^app\/(lib|packages\/[^/]+\/lib)\//, /\.arb$/];
const lock = /^app\/pubspec\.lock$/;

const rows = [];
const shas = git(`-C ${root} log --format=%H --reverse -- app`).trim().split('\n');
for (const sha of shas) {
  const files = git(`-C ${root} show --name-only --format= ${sha}`)
    .split('\n').filter((f) => f.startsWith('app/'));
  const subject = git(`-C ${root} show -s --format=%s ${sha}`).trim();
  const date = git(`-C ${root} show -s --format=%as ${sha}`).trim();
  const nativeFiles = files.filter((f) => native.some((r) => r.test(f)));
  // A lockfile change is native when a plugin (a package with ios/ or
  // android/ code) moved. Approximated: any lock change that adds or bumps a
  // package listed as a Flutter plugin in the lock's own dependency graph.
  let plugin = false;
  if (files.some((f) => lock.test(f))) {
    const diff = git(`-C ${root} show ${sha} -- app/pubspec.lock`);
    plugin = /^[+-]\s{2}(\w*(sign_in|notifications|secure_storage|workmanager|speech|url_launcher|shared_preferences|path_provider|plugin)\w*):/m
      .test(diff);
  }
  const dartFiles = files.filter((f) => dart.some((r) => r.test(f)));
  const kind = nativeFiles.length || plugin ? 'release'
    : dartFiles.length ? 'patch' : 'none';
  rows.push({ date, sha: sha.slice(0, 7), kind, native: nativeFiles.length,
    plugin, dart: dartFiles.length, subject: subject.replaceAll(',', ';') });
}
console.log('date,sha,kind,native_files,plugin_bump,dart_files,subject');
for (const r of rows)
  console.log([r.date, r.sha, r.kind, r.native, r.plugin, r.dart, r.subject].join(','));
const count = (k) => rows.filter((r) => r.kind === k).length;
console.error(`commits touching app/: ${rows.length}; patch: ${count('patch')}; release: ${count('release')}; neither: ${count('none')}`);

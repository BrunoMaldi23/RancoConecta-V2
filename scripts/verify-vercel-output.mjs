import { createHash } from 'node:crypto';
import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const output = join(root, 'vercel_output');
const manifestPath = join(output, '.ranco-build-manifest.json');
const bundlePath = join(output, 'main.dart.js');
const sources = [
  'lib', 'web', 'assets', 'pubspec.yaml', 'pubspec.lock',
  'scripts/deploy-production.ps1', 'scripts/verify-vercel-output.mjs',
  'vercel.json',
];
const textExtensions = /\.(dart|yaml|lock|html|js|json|css|ps1|mjs|svg|xml|txt)$/i;

function files(path) {
  if (!existsSync(path)) return [];
  if (!statSync(path).isDirectory()) return [path];
  const entries = readdirSync(path, { withFileTypes: true });
  if (entries.length === 0) return [];
  return entries.flatMap((entry) => {
    const child = join(path, entry.name);
    return entry.isDirectory() ? files(child) : [child];
  });
}

function sha256(path) {
  return createHash('sha256').update(readFileSync(path)).digest('hex');
}

function sourceHash() {
  const hash = createHash('sha256');
  for (const path of sources.flatMap((item) => files(join(root, item))).sort()) {
    hash.update(relative(root, path).replaceAll('\\', '/'));
    hash.update('\0');
    const content = readFileSync(path);
    hash.update(textExtensions.test(path)
      ? content.toString('utf8').replaceAll('\r\n', '\n')
      : content);
  }
  return hash.digest('hex');
}

const mode = process.argv[2];
const currentSourceHash = sourceHash();
if (mode === '--hash') {
  process.stdout.write(currentSourceHash);
  process.exit(0);
}

if (!existsSync(bundlePath)) throw new Error('vercel_output has no Flutter bundle');

if (mode === '--write') {
  const expected = process.argv[3];
  if (!expected || expected !== currentSourceHash) {
    throw new Error('Sources changed during the production build');
  }
  writeFileSync(manifestPath, JSON.stringify({
    sourceHash: currentSourceHash,
    bundleHash: sha256(bundlePath),
  }));
} else {
  if (!existsSync(manifestPath)) {
    throw new Error('vercel_output has no build manifest; rebuild with deploy-production.ps1');
  }
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  if (manifest.sourceHash !== currentSourceHash ||
      manifest.bundleHash !== sha256(bundlePath)) {
    throw new Error('vercel_output is stale; rebuild with deploy-production.ps1');
  }
  process.stdout.write('Production output matches current sources and bundle.\n');
}

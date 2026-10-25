// Offline integrity gate for media referenced by immutable lesson bundles.
// No network, generation, synthesis or publishing occurs here.
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const FILE_ID = /^[A-Za-z0-9][A-Za-z0-9_.-]*$/;
const SHA256 = /^[a-f0-9]{64}$/;
const MEDIA_LOCATION = {
  'audio/aac': ['audio', '.aac'],
  'audio/wav': ['audio', '.wav'],
  'image/webp': ['images', '.webp'],
  'image/png': ['images', '.png'],
};

const hash = (bytes) => createHash('sha256').update(bytes).digest('hex');
const metadata = (asset) =>
  JSON.stringify(Object.fromEntries(Object.entries(asset).sort(([a], [b]) => a.localeCompare(b))));
const ascii = (bytes, start, end) => bytes.subarray(start, end).toString('ascii');

function validSignature(mime, bytes) {
  if (mime === 'audio/aac')
    return bytes.length >= 2 && bytes[0] === 0xff && (bytes[1] & 0xf6) === 0xf0;
  if (mime === 'audio/wav')
    return bytes.length >= 12 && ascii(bytes, 0, 4) === 'RIFF' && ascii(bytes, 8, 12) === 'WAVE';
  if (mime === 'image/webp')
    return bytes.length >= 12 && ascii(bytes, 0, 4) === 'RIFF' && ascii(bytes, 8, 12) === 'WEBP';
  if (mime === 'image/png')
    return (
      bytes.length >= 8 &&
      bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
    );
  return false;
}

function inside(root, candidate) {
  const relative = path.relative(root, candidate);
  return (
    relative !== '' &&
    !relative.startsWith(`..${path.sep}`) &&
    relative !== '..' &&
    !path.isAbsolute(relative)
  );
}

export function verifyMediaAssets({ courseDir, bundles }) {
  const mediaRoot = path.resolve(courseDir, 'media');
  const declared = new Map();
  let references = 0;

  for (const bundle of bundles) {
    for (const asset of bundle.assets ?? []) {
      references += 1;
      if (!FILE_ID.test(asset.fileId ?? ''))
        throw new Error(`unsafe media fileId: ${asset.fileId}`);
      if (!SHA256.test(asset.sha256 ?? ''))
        throw new Error(`invalid media sha256: ${asset.fileId}`);
      if (!Number.isInteger(asset.bytes) || asset.bytes <= 0)
        throw new Error(`invalid media byte count: ${asset.fileId}`);
      if (!MEDIA_LOCATION[asset.mime]) throw new Error(`unsupported media mime: ${asset.mime}`);
      const prior = declared.get(asset.fileId);
      if (prior && metadata(prior) !== metadata(asset))
        throw new Error(`conflicting metadata for media ${asset.fileId}`);
      declared.set(asset.fileId, prior ?? asset);
    }
  }

  const byMime = {};
  let bytes = 0;
  for (const asset of [...declared.values()].sort((a, b) => a.fileId.localeCompare(b.fileId))) {
    const [directory, extension] = MEDIA_LOCATION[asset.mime];
    const file = path.resolve(mediaRoot, directory, `${asset.fileId}${extension}`);
    if (!inside(mediaRoot, file)) throw new Error(`unsafe media path: ${asset.fileId}`);
    if (!fs.existsSync(file)) throw new Error(`missing media ${asset.fileId}: ${file}`);
    const realFile = fs.realpathSync(file);
    const realRoot = fs.realpathSync(mediaRoot);
    if (!inside(realRoot, realFile))
      throw new Error(`media escapes course directory: ${asset.fileId}`);
    const contents = fs.readFileSync(realFile);
    if (contents.length !== asset.bytes)
      throw new Error(
        `byte count mismatch for media ${asset.fileId}: expected ${asset.bytes}, got ${contents.length}`,
      );
    const actualHash = hash(contents);
    if (actualHash !== asset.sha256)
      throw new Error(
        `sha256 mismatch for media ${asset.fileId}: expected ${asset.sha256}, got ${actualHash}`,
      );
    if (!validSignature(asset.mime, contents))
      throw new Error(`invalid media signature for ${asset.fileId} (${asset.mime})`);
    bytes += contents.length;
    byMime[asset.mime] = (byMime[asset.mime] ?? 0) + 1;
  }
  return { references, assets: declared.size, bytes, byMime };
}

export function verifyPublishedMedia(repoRoot) {
  const summaries = [];
  const contentRoot = path.join(repoRoot, 'content');
  for (const courseId of fs.readdirSync(contentRoot)) {
    const courseDir = path.join(contentRoot, courseId);
    const dist = path.join(courseDir, 'dist');
    if (!fs.existsSync(dist)) continue;
    for (const version of fs.readdirSync(dist)) {
      const versionDir = path.join(dist, version);
      const manifest = JSON.parse(fs.readFileSync(path.join(versionDir, 'manifest.json'), 'utf8'));
      const publish = JSON.parse(fs.readFileSync(path.join(versionDir, 'publish.json'), 'utf8'));
      const paths = new Map(publish.files.map((file) => [file.fileId, file.path]));
      const bundles = [...manifest.bundles, manifest.placementBundle].map((index) => {
        const relative = paths.get(index.fileId);
        if (!relative) throw new Error(`bundle ${index.fileId} missing from publish.json`);
        const file = path.resolve(versionDir, relative);
        if (!inside(versionDir, file)) throw new Error(`unsafe bundle path: ${relative}`);
        return JSON.parse(fs.readFileSync(file, 'utf8'));
      });
      summaries.push({ courseId, version, ...verifyMediaAssets({ courseDir, bundles }) });
    }
  }
  return summaries;
}

const invoked = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (invoked) {
  const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
  console.log(JSON.stringify({ status: 'PASS', courses: verifyPublishedMedia(repoRoot) }));
}

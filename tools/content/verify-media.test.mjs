import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { verifyMediaAssets } from './verify-media.mjs';

const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');

function fixture() {
  const courseDir = fs.mkdtempSync(path.join(os.tmpdir(), 'coc-media-'));
  fs.mkdirSync(path.join(courseDir, 'media/audio'), { recursive: true });
  fs.mkdirSync(path.join(courseDir, 'media/images'), { recursive: true });
  const audio = Buffer.concat([Buffer.from([0xff, 0xf1, 0x50, 0x80]), Buffer.from('aac fixture')]);
  const image = Buffer.concat([
    Buffer.from('RIFF'),
    Buffer.from([12, 0, 0, 0]),
    Buffer.from('WEBPVP8 fixture'),
  ]);
  fs.writeFileSync(path.join(courseDir, 'media/audio/a.lesson.n.aac'), audio);
  fs.writeFileSync(path.join(courseDir, 'media/images/i.lesson.webp'), image);
  const assets = [
    {
      fileId: 'a.lesson.n',
      mime: 'audio/aac',
      bytes: audio.length,
      sha256: sha256(audio),
      altText: 'Lesson audio',
    },
    {
      fileId: 'i.lesson',
      mime: 'image/webp',
      bytes: image.length,
      sha256: sha256(image),
      altText: 'Lesson image',
    },
  ];
  return { courseDir, assets, image, totalBytes: audio.length + image.length };
}

test('verifies every reference while hashing identical assets once', () => {
  const f = fixture();
  try {
    const summary = verifyMediaAssets({
      courseDir: f.courseDir,
      bundles: [{ assets: f.assets }, { assets: f.assets }],
    });
    assert.deepEqual(summary, {
      references: 4,
      assets: 2,
      bytes: f.totalBytes,
      byMime: { 'audio/aac': 1, 'image/webp': 1 },
    });
  } finally {
    fs.rmSync(f.courseDir, { recursive: true, force: true });
  }
});

test('rejects missing and tampered media bytes', () => {
  const f = fixture();
  try {
    fs.rmSync(path.join(f.courseDir, 'media/images/i.lesson.webp'));
    assert.throws(
      () => verifyMediaAssets({ courseDir: f.courseDir, bundles: [{ assets: f.assets }] }),
      /missing media.*i\.lesson/i,
    );
    const tampered = Buffer.from(f.image);
    tampered[tampered.length - 1] ^= 1;
    fs.writeFileSync(path.join(f.courseDir, 'media/images/i.lesson.webp'), tampered);
    assert.throws(
      () => verifyMediaAssets({ courseDir: f.courseDir, bundles: [{ assets: f.assets }] }),
      /sha256 mismatch.*i\.lesson/i,
    );
  } finally {
    fs.rmSync(f.courseDir, { recursive: true, force: true });
  }
});

test('rejects conflicting duplicate metadata and unsafe file ids', () => {
  const f = fixture();
  try {
    const conflict = { ...f.assets[0], altText: 'Different declaration' };
    assert.throws(
      () =>
        verifyMediaAssets({
          courseDir: f.courseDir,
          bundles: [{ assets: f.assets }, { assets: [conflict] }],
        }),
      /conflicting metadata.*a\.lesson\.n/i,
    );
    assert.throws(
      () =>
        verifyMediaAssets({
          courseDir: f.courseDir,
          bundles: [{ assets: [{ ...f.assets[0], fileId: '../escape' }] }],
        }),
      /unsafe media fileId/i,
    );
  } finally {
    fs.rmSync(f.courseDir, { recursive: true, force: true });
  }
});

test('rejects a consistently hashed text placeholder', () => {
  const f = fixture();
  try {
    const placeholder = Buffer.from('not a real media file');
    const asset = {
      ...f.assets[1],
      bytes: placeholder.length,
      sha256: sha256(placeholder),
    };
    fs.writeFileSync(path.join(f.courseDir, 'media/images/i.lesson.webp'), placeholder);
    assert.throws(
      () => verifyMediaAssets({ courseDir: f.courseDir, bundles: [{ assets: [asset] }] }),
      /invalid media signature.*i\.lesson/i,
    );
  } finally {
    fs.rmSync(f.courseDir, { recursive: true, force: true });
  }
});

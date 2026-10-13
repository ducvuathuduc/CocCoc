// `node tools/content/generate-audio.mjs [--course vi_en] [--version v2] [--only a.u1.s1,...] [--limit N]
//   [--concurrency 3] [--check]`
// Lesson audio for every key in content/<course>/dist/<version>/audio-catalog.json (P7-AUDIO-001):
// Azure neural TTS (en-US), one AAC-LC file per asset fileId under content/<course>/media/audio/
// (`<key>.n.aac` normal, `<key>.s.aac` slow 0.75x for the turtle button; words: `.n` only), plus
// content/<course>/media/audio-manifest.json (sha256/bytes/durationMs/voice per fileId) which
// build-course.mjs reads so bundle asset hashes are the real file hashes.
//
// Voices (consistent cast mapping, see CAST below): female cast (Mai, Anna, Linh, Kiko, Rosa, Mrs …)
// and the narrator speak with en-US-AvaNeural, male cast (Tom, Nam, Huy, Long, Mr …) with
// en-US-AndrewNeural, and the dialogue partner (Lily in the dialogue exercise) with en-US-EmmaNeural.
// A sentence in which a cast member introduces themself ("I am Tom", "My name is Mai") uses that
// person's voice; any other sentence gets a deterministic narrator/male alternation by key hash, so
// regeneration never reshuffles voices. Tile words use the narrator voice.
//
// Transport: the Azure key never enters this sandbox or the repo. It lives only in the env of the
// server-only Appwrite function `coc-tts` (work/tts-fn, execute permission empty), which takes an
// SSML document and returns the MP3 bytes. Several clips are synthesized per request separated by
// long SSML breaks and split back here with ffmpeg silencedetect; a batch whose split count does not
// match falls back to one request per clip. Each clip is trimmed to ~80 ms head / 120 ms tail
// silence, loudness-normalised and encoded to mono 24 kHz AAC-LC 48 kbit/s ADTS (`audio/aac`, the
// OpenAPI MediaAsset enum). Unchanged clips (same text/voice/speed and file present) are skipped.
// Env: APPWRITE_API_KEY (server key; NODE_USE_ENV_PROXY=1 when proxy-injected), APPWRITE_ENDPOINT,
// APPWRITE_PROJECT_ID. --check exits 1 when any catalog clip is missing or stale (no network).
import { createHash } from 'node:crypto';
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const arg = (name, fallback) => {
  const i = process.argv.indexOf(`--${name}`);
  return i > 0 ? process.argv[i + 1] : fallback;
};
const courseId = arg('course', 'vi_en');
const versionId = arg('version', 'v2');
const only = arg('only', '')
  .split(',')
  .filter(Boolean);
const limit = Number(arg('limit', '0')) || Infinity;
const concurrency = Number(arg('concurrency', '3'));
const checkOnly = process.argv.includes('--check');
const BATCH = Number(arg('batch', '10'));

export const VOICES = {
  narrator: 'en-US-AvaNeural',
  male: 'en-US-AndrewNeural',
  partner: 'en-US-EmmaNeural',
};
const CAST = {
  female: ['Mai', 'Anna', 'Linh', 'Kiko', 'Rosa', 'Lan', 'Hoa', 'Lily', 'Mrs', 'Ms', 'Mom', 'Chi'],
  male: ['Tom', 'Nam', 'Huy', 'Long', 'Minh', 'Ben', 'Mr', 'Dad', 'Duc', 'Khoa'],
};
export const PROVIDER = 'azure-tts';
export const SLOW_RATE = '-25%';
// --catalog <json> --out <dir>: synthesize another catalog (same shape) into <dir>/<fileId>.aac with
// <dir>/audio-manifest.json; used for the small clip set bundled with the app's mock course
// (content/vi_en/source/mock-audio.json -> apps/mobile/assets/lesson_audio/).
const catalogPath = arg('catalog', '')
  ? path.resolve(arg('catalog', ''))
  : path.join(root, 'content', courseId, 'dist', versionId, 'audio-catalog.json');
const MEDIA = path.join(root, 'content', courseId, 'media');
const AUDIO_DIR = arg('out', '') ? path.resolve(arg('out', '')) : path.join(MEDIA, 'audio');
const MANIFEST = arg('out', '')
  ? path.join(AUDIO_DIR, 'audio-manifest.json')
  : path.join(MEDIA, 'audio-manifest.json');
const sha256 = (b) => createHash('sha256').update(b).digest('hex');

export function voiceFor(item) {
  if (item.kind === 'word') return VOICES.narrator;
  if (item.kind === 'dialogueLine') return VOICES.partner;
  const m = item.text.match(/\b(?:I am|I'm|My name is|This is)\s+(?:Mr\.?\s+|Mrs\.?\s+)?([A-Z][a-z]+)/);
  if (m) {
    if (CAST.female.includes(m[1])) return VOICES.narrator;
    if (CAST.male.includes(m[1])) return VOICES.male;
  }
  return parseInt(sha256(item.key).slice(0, 8), 16) % 2 === 0 ? VOICES.narrator : VOICES.male;
}

function clipsFromCatalog(catalog) {
  const clips = [];
  for (const item of catalog.items) {
    const speeds = item.kind === 'word' ? { n: 1 } : catalog.speeds;
    for (const [suffix, speed] of Object.entries(speeds)) {
      clips.push({
        fileId: `${item.key}.${suffix}`,
        text: item.text,
        kind: item.kind,
        speed,
        voice: voiceFor(item),
      });
    }
  }
  return clips;
}

const esc = (s) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
function ssmlFor(clips) {
  const body = clips
    .map((c) => {
      const text = esc(c.text);
      const inner = c.speed === 1 ? text : `<prosody rate="${SLOW_RATE}">${text}</prosody>`;
      return `<voice name="${c.voice}">${inner}<break time="2500ms"/></voice>`;
    })
    .join('');
  return `<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">${body}</speak>`;
}

let functions;
async function tts(ssml) {
  if (!functions) {
    const { Client, Functions } = await import('node-appwrite');
    const client = new Client()
      .setEndpoint(process.env.APPWRITE_ENDPOINT ?? 'https://sgp.cloud.appwrite.io/v1')
      .setProject(process.env.APPWRITE_PROJECT_ID ?? '6acc656d0025cc57bd81')
      .setKey(process.env.APPWRITE_API_KEY ?? '');
    functions = new Functions(client);
  }
  for (let attempt = 1; ; attempt++) {
    let detail;
    try {
      const e = await functions.createExecution({
        functionId: 'coc-tts',
        body: JSON.stringify({ ssml, format: 'audio-24khz-96kbitrate-mono-mp3' }),
        async: false,
        method: 'POST',
        headers: { 'content-type': 'application/json' },
      });
      const j = JSON.parse(e.responseBody || '{}');
      if (j.mp3) return Buffer.from(j.mp3, 'base64');
      detail = `${e.responseStatusCode} ${j.error ?? ''} ${j.detail ?? ''} ${e.errors ?? ''}`.trim();
    } catch (error) {
      detail = error?.message ?? String(error);
    }
    if (attempt >= 6) throw new Error(`tts failed: ${detail}`);
    const wait = /429/.test(detail) ? 15000 : 2000 * attempt;
    console.error(`retry ${attempt} in ${wait}ms: ${detail.slice(0, 160)}`);
    await new Promise((r) => setTimeout(r, wait));
  }
}

const ff = (args, input) =>
  execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', ...args], {
    input,
    maxBuffer: 1 << 28,
  });
// ffmpeg prints silencedetect/progress lines on stderr.
function runFfInfo(args) {
  const r = spawnSync('ffmpeg', ['-hide_banner', '-nostats', '-stats', ...args, '-f', 'null', '-'], {
    encoding: 'utf8',
    maxBuffer: 1 << 26,
  });
  return String(r.stderr ?? '');
}

const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'coc-audio-'));
function decodePcm(mp3Path) {
  // 24 kHz mono float WAV for exact sample-domain cuts.
  const wav = mp3Path.replace(/\.mp3$/, '.wav');
  ff(['-y', '-i', mp3Path, '-ac', '1', '-ar', '24000', wav]);
  return wav;
}
function durationOf(file) {
  const out = runFfInfo(['-i', file]);
  const m = [...out.matchAll(/time=(\d+):(\d+):([\d.]+)/g)].pop();
  if (!m) throw new Error(`no duration for ${file}`);
  return Math.round((Number(m[1]) * 3600 + Number(m[2]) * 60 + Number(m[3])) * 1000);
}
function silences(file) {
  const out = runFfInfo(['-i', file, '-af', 'silencedetect=n=-50dB:d=1.4']);
  const s = [];
  let start = null;
  for (const line of out.split('\n')) {
    const a = line.match(/silence_start: ([\d.]+)/);
    if (a) start = Number(a[1]);
    const b = line.match(/silence_end: ([\d.]+)/);
    if (b && start !== null) {
      s.push([start, Number(b[1])]);
      start = null;
    }
  }
  if (start !== null) s.push([start, Infinity]);
  return s;
}
const TRIM =
  'silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.08,areverse,' +
  'silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.12,areverse,' +
  'loudnorm=I=-18:TP=-1.5:LRA=11';
function encodeSegment(wav, from, to, out) {
  const span = Number.isFinite(to) ? ['-t', String(Math.max(0.05, to - from))] : [];
  ff([
    '-y',
    '-ss',
    String(from),
    ...span,
    '-i',
    wav,
    '-af',
    TRIM,
    '-ac',
    '1',
    '-ar',
    '24000',
    '-c:a',
    'aac',
    '-b:a',
    '48k',
    '-f',
    'adts',
    out,
  ]);
}

async function synthBatch(clips, tag) {
  const mp3 = path.join(TMP, `${tag}.mp3`);
  fs.writeFileSync(mp3, await tts(ssmlFor(clips)));
  const wav = decodePcm(mp3);
  const sil = silences(wav);
  // Every clip is followed by a 2.5 s break: expect exactly clips.length long silences
  // (the last may run to the end of the file).
  if (sil.length !== clips.length) {
    if (clips.length === 1 && sil.length === 0) sil.push([Infinity, Infinity]);
    else return false;
  }
  let from = 0;
  clips.forEach((clip, i) => {
    const [s, e] = sil[i];
    const cut = Number.isFinite(e) ? (s + e) / 2 : s;
    const out = path.join(AUDIO_DIR, `${clip.fileId}.aac`);
    encodeSegment(wav, from, Number.isFinite(cut) ? cut : Infinity, out);
    from = Number.isFinite(e) ? (s + e) / 2 : from;
  });
  return true;
}

function entryFor(clip) {
  const file = path.join(AUDIO_DIR, `${clip.fileId}.aac`);
  const bytes = fs.readFileSync(file);
  return {
    text: clip.text,
    voice: clip.voice,
    speed: clip.speed,
    provider: PROVIDER,
    sha256: sha256(bytes),
    bytes: bytes.length,
    durationMs: durationOf(file),
  };
}

async function main() {
  const catalog = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));
  fs.mkdirSync(AUDIO_DIR, { recursive: true });
  const manifest = fs.existsSync(MANIFEST)
    ? JSON.parse(fs.readFileSync(MANIFEST, 'utf8'))
    : { courseId, format: 'audio/aac', files: {} };
  const all = clipsFromCatalog(catalog);
  const fresh = (c) => {
    const m = manifest.files[c.fileId];
    const file = path.join(AUDIO_DIR, `${c.fileId}.aac`);
    return (
      m &&
      m.text === c.text &&
      m.voice === c.voice &&
      m.speed === c.speed &&
      fs.existsSync(file) &&
      sha256(fs.readFileSync(file)) === m.sha256
    );
  };
  let todo = all.filter((c) => (only.length ? only.some((k) => c.fileId.startsWith(k)) : true));
  todo = todo.filter((c) => !fresh(c)).slice(0, limit);
  if (checkOnly) {
    const stale = all.filter((c) => !fresh(c));
    console.log(JSON.stringify({ clips: all.length, stale: stale.length, sample: stale.slice(0, 5).map((c) => c.fileId) }));
    process.exit(stale.length ? 1 : 0);
  }
  console.error(JSON.stringify({ step: 'plan', clips: all.length, todo: todo.length }));
  const batches = [];
  for (let i = 0; i < todo.length; i += BATCH) batches.push(todo.slice(i, i + BATCH));
  let done = 0;
  let fallbacks = 0;
  const save = () => {
    const files = Object.fromEntries(Object.entries(manifest.files).sort(([a], [b]) => (a < b ? -1 : 1)));
    fs.writeFileSync(MANIFEST, `${JSON.stringify({ ...manifest, voices: VOICES, slowRate: SLOW_RATE, files }, null, 1)}\n`);
  };
  const queue = batches.map((b, i) => ({ b, i }));
  await Promise.all(
    Array.from({ length: concurrency }, async () => {
      for (let job = queue.shift(); job; job = queue.shift()) {
        const ok = await synthBatch(job.b, `b${job.i}`);
        if (!ok) {
          fallbacks++;
          for (const [k, clip] of job.b.entries()) {
            if (!(await synthBatch([clip], `b${job.i}-${k}`)))
              throw new Error(`cannot split single clip ${clip.fileId}`);
          }
        }
        for (const clip of job.b) manifest.files[clip.fileId] = entryFor(clip);
        done += job.b.length;
        if (job.i % 5 === 0) {
          save();
          console.error(JSON.stringify({ step: 'progress', done, of: todo.length, fallbacks }));
        }
      }
    }),
  );
  // Drop clips no longer in the catalog.
  const live = new Set(all.map((c) => c.fileId));
  for (const id of Object.keys(manifest.files)) if (!live.has(id)) delete manifest.files[id];
  save();
  fs.rmSync(TMP, { recursive: true, force: true });
  const voices = {};
  for (const c of all) voices[c.voice] = (voices[c.voice] ?? 0) + 1;
  console.log(JSON.stringify({ status: 'PASS', clips: all.length, generated: todo.length, fallbacks, voices }));
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await main();
  process.exit(0);
}

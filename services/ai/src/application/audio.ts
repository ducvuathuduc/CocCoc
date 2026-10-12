// Recorded WAV validation for TURN speech and assessment (OpenAPI: WAV <= 15 s, <= 480044 bytes,
// 16 kHz mono 16-bit PCM). Integrity: SHA-256 of the decoded bytes must equal audioSha256.
import { ServiceError } from '../../../shared/src/errors.js';
import { sha256Hex } from './deps.js';

export const MAX_WAV_BYTES = 480044;
const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;

function bad(reason: string): never {
  throw new ServiceError('INVALID_AUDIO', { details: { reason } });
}

/** Returns the audio duration in whole seconds (rounded up). Never stores or logs the audio. */
export function validateWav(wavBase64: string, audioSha256: string): number {
  if (wavBase64.length % 4 !== 0 || !BASE64.test(wavBase64)) bad('BASE64');
  const bytes = Buffer.from(wavBase64, 'base64');
  if (bytes.length > MAX_WAV_BYTES) bad('TOO_LARGE');
  if (sha256Hex(bytes) !== audioSha256) bad('SHA256_MISMATCH');
  if (
    bytes.length < 44 ||
    bytes.toString('ascii', 0, 4) !== 'RIFF' ||
    bytes.toString('ascii', 8, 12) !== 'WAVE'
  ) {
    bad('NOT_WAV');
  }
  let offset = 12;
  let format: { channels: number; rate: number; bits: number; audio: number } | undefined;
  let dataBytes: number | undefined;
  while (offset + 8 <= bytes.length) {
    const id = bytes.toString('ascii', offset, offset + 4);
    const size = bytes.readUInt32LE(offset + 4);
    const body = offset + 8;
    if (id === 'fmt ' && body + 16 <= bytes.length) {
      format = {
        audio: bytes.readUInt16LE(body),
        channels: bytes.readUInt16LE(body + 2),
        rate: bytes.readUInt32LE(body + 4),
        bits: bytes.readUInt16LE(body + 14),
      };
    } else if (id === 'data') {
      dataBytes = Math.min(size, bytes.length - body);
      break;
    }
    offset = body + size + (size % 2);
  }
  if (!format || format.audio !== 1 || format.channels !== 1 || format.rate !== 16000) {
    bad('FORMAT');
  }
  if (format.bits !== 16) bad('FORMAT');
  if (dataBytes === undefined || dataBytes <= 0) bad('NO_DATA');
  const seconds = dataBytes / (16000 * 2);
  if (seconds > 15) bad('TOO_LONG');
  return Math.max(1, Math.ceil(seconds));
}

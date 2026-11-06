/** Checks a browser upload really is the format the bundle claims, before it reaches the media tree. */

/**
 * `tools/content/generate-audio.mjs` writes ADTS AAC and the manifest says `audio/aac`, so a clip whose
 * first frame header does not decode is either a wrong extension or a truncated export. The frame length
 * is checked against the file so a stray `FF F1` in some other container does not pass.
 */
export function isAdtsAac(bytes: Uint8Array): boolean {
  if (bytes.length < 9) return false;
  const sync = bytes[0] === 0xff && (bytes[1] & 0xf0) === 0xf0;
  const layer = (bytes[1] & 0x06) === 0; // AAC in ADTS always uses the two layer bits 00
  if (!sync || !layer) return false;
  const frameLength = ((bytes[3] & 0x03) << 13) | (bytes[4] << 5) | (bytes[5] >> 3);
  return frameLength >= 7 && frameLength <= bytes.length;
}

export interface WebpSize {
  width: number;
  height: number;
}

function fourcc(bytes: Uint8Array, at: number): string {
  return String.fromCharCode(bytes[at], bytes[at + 1], bytes[at + 2], bytes[at + 3]);
}

/**
 * Width and height of a WebP, covering all three bitstreams (`VP8 ` lossy, `VP8L` lossless, `VP8X`
 * extended). `build-course.mjs:216` declares every image asset as 512x512 regardless of the file, so
 * this is the only way to catch a picture that would ship mislabelled.
 */
export function webpSize(bytes: Uint8Array): WebpSize | null {
  if (bytes.length < 21 || fourcc(bytes, 0) !== 'RIFF' || fourcc(bytes, 8) !== 'WEBP') return null;
  const chunk = fourcc(bytes, 12);
  const payload = 20;
  if (chunk === 'VP8L') {
    if (bytes[payload] !== 0x2f) return null;
    const bits =
      bytes[payload + 1] |
      (bytes[payload + 2] << 8) |
      ((bytes[payload + 3] & 0xff) << 16) |
      ((bytes[payload + 4] & 0xff) << 24);
    return { width: (bits & 0x3fff) + 1, height: ((bits >> 14) & 0x3fff) + 1 };
  }
  if (chunk === 'VP8 ') {
    // frame tag (3 bytes) + start code 0x9d 0x01 0x2a, then two little-endian 14-bit sizes.
    if (bytes[payload + 6] !== 0x9d || bytes[payload + 8] !== 0x2a) return null;
    const width = (bytes[payload + 9] | (bytes[payload + 10] << 8)) & 0x3fff;
    const height = (bytes[payload + 11] | (bytes[payload + 12] << 8)) & 0x3fff;
    return { width, height };
  }
  if (chunk === 'VP8X') {
    const le24 = (at: number) => bytes[at] | (bytes[at + 1] << 8) | (bytes[at + 2] << 16);
    return { width: le24(24) + 1, height: le24(27) + 1 };
  }
  return null;
}

/** The picture the app draws is a fixed 512x512 tile, so anything else is a mis-authored asset. */
export const LESSON_IMAGE_SIZE = 512;

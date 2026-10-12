// Content integrity: canonical JSON, SHA-256 and Ed25519 signatures for manifests and bundles.
//
// - manifestHash  = sha256(canonical(manifest without bundles, placementBundle, manifestHash,
//                   signature, signatureKeyId)) -- the course *structure* hash. Bundles embed it,
//                   which avoids a manifest<->bundle hash cycle.
// - manifest.signature = Ed25519(canonical(manifest without signature, signatureKeyId)), so the
//                   signature covers the structure hash and every bundle sha256.
// - bundle.signature   = Ed25519(canonical(bundle without signature, signatureKeyId)).
// - A published file is the canonical JSON text; BundleIndex.sha256 / manifestSha256 hash its bytes.
import {
  createHash,
  createPrivateKey,
  createPublicKey,
  sign,
  verify,
  type KeyObject,
} from 'node:crypto';
import type { CourseManifest, LessonBundle } from './types.js';

export function canonicalJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map((v) => canonicalJson(v ?? null)).join(',')}]`;
  if (value && typeof value === 'object') {
    const entries = Object.entries(value as Record<string, unknown>)
      .filter(([, v]) => v !== undefined)
      .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
    return `{${entries.map(([k, v]) => `${JSON.stringify(k)}:${canonicalJson(v)}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

export function sha256(text: string | Uint8Array): string {
  return createHash('sha256').update(text).digest('hex');
}

function omit<T extends object>(value: T, keys: readonly string[]): Record<string, unknown> {
  return Object.fromEntries(Object.entries(value).filter(([key]) => !keys.includes(key)));
}

export function manifestStructureHash(
  manifest: Omit<CourseManifest, 'manifestHash' | 'signature' | 'signatureKeyId'>,
): string {
  return sha256(
    canonicalJson(
      omit(manifest, ['bundles', 'placementBundle', 'manifestHash', 'signature', 'signatureKeyId']),
    ),
  );
}

export function manifestSigningInput(manifest: object): string {
  return canonicalJson(omit(manifest, ['signature', 'signatureKeyId']));
}
export function bundleSigningInput(bundle: object): string {
  return canonicalJson(omit(bundle, ['signature', 'signatureKeyId']));
}

/** Ed25519 key from a 32-byte seed (PKCS#8 DER prefix for id-Ed25519). */
export function ed25519FromSeed(seed: Buffer): KeyObject {
  if (seed.length !== 32) throw new Error('CONTENT_KEY_SEED_LENGTH');
  const der = Buffer.concat([Buffer.from('302e020100300506032b657004220420', 'hex'), seed]);
  return createPrivateKey({ key: der, format: 'der', type: 'pkcs8' });
}

export function signText(privateKey: KeyObject, text: string): string {
  return sign(null, Buffer.from(text, 'utf8'), privateKey).toString('base64url');
}

export interface ContentKey {
  keyId: string;
  publicKey: KeyObject;
}
export type ContentKeyring = ReadonlyMap<string, ContentKey>;

export function verifyText(
  keyring: ContentKeyring,
  keyId: string,
  text: string,
  signature: string,
): boolean {
  const key = keyring.get(keyId);
  if (!key || !/^[A-Za-z0-9_-]{86}$/.test(signature)) return false;
  try {
    return verify(
      null,
      Buffer.from(text, 'utf8'),
      key.publicKey,
      Buffer.from(signature, 'base64url'),
    );
  } catch {
    return false;
  }
}

/** Raw 32-byte Ed25519 public key hex -> KeyObject (SPKI DER prefix). */
export function publicKeyFromHex(hex: string): KeyObject {
  if (!/^[0-9a-f]{64}$/i.test(hex)) throw new Error('CONTENT_PUBLIC_KEY_FORMAT');
  const der = Buffer.concat([
    Buffer.from('302a300506032b6570032100', 'hex'),
    Buffer.from(hex, 'hex'),
  ]);
  return createPublicKey({ key: der, format: 'der', type: 'spki' });
}

export function publicKeyHex(key: KeyObject): string {
  const der = createPublicKey(key).export({ format: 'der', type: 'spki' });
  return Buffer.from(der).subarray(-32).toString('hex');
}

/** Hosted keyring from COC_CONTENT_PUBLIC_KEYS: [{"keyId","publicKeyHex"}]. Unset -> empty (fail closed). */
export function parseContentKeyring(raw: string | undefined): ContentKeyring {
  const ring = new Map<string, ContentKey>();
  if (!raw) return ring;
  const parsed: unknown = JSON.parse(raw);
  if (!Array.isArray(parsed)) throw new Error('INVALID_CONTENT_KEYRING');
  for (const entry of parsed as { keyId?: unknown; publicKeyHex?: unknown }[]) {
    if (typeof entry.keyId !== 'string' || typeof entry.publicKeyHex !== 'string') {
      throw new Error('INVALID_CONTENT_KEYRING');
    }
    ring.set(entry.keyId, { keyId: entry.keyId, publicKey: publicKeyFromHex(entry.publicKeyHex) });
  }
  return ring;
}

export function verifyBundle(keyring: ContentKeyring, bundle: LessonBundle): boolean {
  return verifyText(keyring, bundle.signatureKeyId, bundleSigningInput(bundle), bundle.signature);
}
export function verifyManifest(keyring: ContentKeyring, manifest: CourseManifest): boolean {
  return (
    manifest.manifestHash === manifestStructureHash(manifest) &&
    verifyText(keyring, manifest.signatureKeyId, manifestSigningInput(manifest), manifest.signature)
  );
}

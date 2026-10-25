// AMQP event envelope (ADR-0018 "AMQP producer authentication"). The broker carries the
// unchanged versioned BusinessEvent inside a signed envelope:
//   { v: 1, keyId, sender, bodyHash, signature, event }
//   bodyHash  = canonicalBodyHash(event)            (same identity as the direct relay/inbox)
//   signature = HMAC-SHA256(secret, "coc-amqp-v1\n" + keyId + "\n" + sender + "\n" + bodyHash)
// The key comes from the existing COC_SERVICE_KEYS keyring (domain-separated from the HTTP
// signing string). Verification needs the key ID in the receiver's keyring, the key's sender to
// equal event.producer, and the recomputed hash to match. There is deliberately NO freshness
// window: a queued event may be delivered long after creation (> 300 s); replay protection is the
// durable inbox (eventId + bodyHash). Key rotation: add the new key to every receiver first,
// then make it the producer's first key for its sender, then retire the old key after the
// retention window (docs/devops/OPERATIONS.md).
import { createHmac, timingSafeEqual } from 'node:crypto';
import { ServiceError } from './errors.js';
import type { BusinessEvent, EventOwner } from './ports.js';
import type { Keyring, ServiceKey } from './service-hmac.js';
import { canonicalBodyHash, validateEventEnvelope } from './transport.js';

export const ENVELOPE_VERSION = 1;
export const MAX_ENVELOPE_BYTES = 64_000;
const OWNERS = new Set<string>(['learning', 'progress', 'ai']);
const KEY_ID = /^[A-Za-z0-9._-]{1,64}$/;
const HEX64 = /^[0-9a-f]{64}$/;

export interface SignedEnvelope {
  v: 1;
  keyId: string;
  sender: EventOwner;
  bodyHash: string;
  signature: string;
  event: BusinessEvent;
}

function mac(key: ServiceKey, sender: string, bodyHash: string): Buffer {
  return createHmac('sha256', key.secret)
    .update(`coc-amqp-v1\n${key.keyId}\n${sender}\n${bodyHash}`, 'utf8')
    .digest();
}

/** The producer's signing key: the first key in the keyring whose sender is this owner. */
export function signingKeyFor(keyring: Keyring | undefined, owner: EventOwner): ServiceKey | undefined {
  return keyring ? [...keyring.values()].find((key) => key.sender === owner) : undefined;
}

export function signEnvelope(key: ServiceKey, event: BusinessEvent): Buffer {
  if (!OWNERS.has(key.sender) || event.producer !== key.sender) {
    throw new ServiceError('FORBIDDEN', { details: { reason: 'PRODUCER_KEY_MISMATCH' } });
  }
  const bodyHash = canonicalBodyHash(event);
  const envelope: SignedEnvelope = {
    v: ENVELOPE_VERSION,
    keyId: key.keyId,
    sender: key.sender as EventOwner,
    bodyHash,
    signature: mac(key, key.sender, bodyHash).toString('hex'),
    event,
  };
  return Buffer.from(JSON.stringify(envelope), 'utf8');
}

export interface VerifiedEnvelope {
  event: BusinessEvent;
  bodyHash: string;
  sender: EventOwner;
  keyId: string;
}

/**
 * Verify a raw broker message body. Throws ServiceError: VALIDATION_ERROR for a malformed
 * envelope/event, AUTH_REQUIRED for an unknown key or bad signature, FORBIDDEN when the signer is
 * not the event's producer. Never trusts AMQP headers.
 */
export function verifyEnvelope(keyring: Keyring | undefined, raw: Buffer): VerifiedEnvelope {
  if (!keyring || keyring.size === 0) throw new ServiceError('AUTH_REQUIRED');
  if (raw.length > MAX_ENVELOPE_BYTES) throw new ServiceError('PAYLOAD_TOO_LARGE');
  let parsed: Partial<SignedEnvelope> | null;
  try {
    parsed = JSON.parse(raw.toString('utf8')) as Partial<SignedEnvelope>;
  } catch {
    throw new ServiceError('VALIDATION_ERROR', { details: { field: 'envelope' } });
  }
  if (
    !parsed ||
    typeof parsed !== 'object' ||
    parsed.v !== ENVELOPE_VERSION ||
    typeof parsed.keyId !== 'string' ||
    !KEY_ID.test(parsed.keyId) ||
    typeof parsed.sender !== 'string' ||
    !OWNERS.has(parsed.sender) ||
    typeof parsed.bodyHash !== 'string' ||
    !HEX64.test(parsed.bodyHash) ||
    typeof parsed.signature !== 'string' ||
    !HEX64.test(parsed.signature)
  ) {
    throw new ServiceError('VALIDATION_ERROR', { details: { field: 'envelope' } });
  }
  const key = keyring.get(parsed.keyId);
  if (!key) throw new ServiceError('AUTH_REQUIRED');
  const event = validateEventEnvelope(parsed.event);
  const bodyHash = canonicalBodyHash(event);
  const expected = mac(key, parsed.sender, bodyHash);
  if (bodyHash !== parsed.bodyHash || !timingSafeEqual(expected, Buffer.from(parsed.signature, 'hex'))) {
    throw new ServiceError('AUTH_REQUIRED');
  }
  if (key.sender !== parsed.sender || event.producer !== parsed.sender) {
    throw new ServiceError('FORBIDDEN');
  }
  return { event, bodyHash, sender: parsed.sender as EventOwner, keyId: key.keyId };
}

// Strict request-body validation for Learning mutations (OpenAPI request schemas; unknown fields
// rejected). Small hand-written checks keep the hosted bundle free of a schema engine.
import { ServiceError } from '../../../shared/src/errors.js';
import type { Answer } from '../content/types.js';

const ID = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/;
const SHA = /^[a-f0-9]{64}$/;

function fail(field: string, reason = 'INVALID'): never {
  throw new ServiceError('VALIDATION_ERROR', { details: { field, reason } });
}
export function object(
  value: unknown,
  field: string,
  allowed: readonly string[],
  required: readonly string[],
): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) fail(field);
  const record = value as Record<string, unknown>;
  for (const key of Object.keys(record))
    if (!allowed.includes(key)) fail(`${field}.${key}`, 'UNKNOWN_FIELD');
  for (const key of required) if (record[key] === undefined) fail(`${field}.${key}`, 'REQUIRED');
  return record;
}
export const id = (value: unknown, field: string): string =>
  typeof value === 'string' && ID.test(value) ? value : fail(field);
export const int = (value: unknown, field: string, min: number, max: number): number =>
  Number.isInteger(value) && (value as number) >= min && (value as number) <= max
    ? (value as number)
    : fail(field);
export const bool = (value: unknown, field: string): boolean =>
  typeof value === 'boolean' ? value : fail(field);
export function oneOf<T extends string>(value: unknown, field: string, values: readonly T[]): T {
  return typeof value === 'string' && (values as readonly string[]).includes(value)
    ? (value as T)
    : fail(field);
}
export const sha = (value: unknown, field: string): string =>
  typeof value === 'string' && SHA.test(value) ? value : fail(field);
export function text(value: unknown, field: string, max: number): string {
  return typeof value === 'string' && value.length <= max ? value : fail(field);
}

export function answer(value: unknown, field = 'answer'): Answer {
  const kind = (value as { kind?: unknown } | null)?.kind;
  switch (kind) {
    case 'text': {
      const a = object(value, field, ['kind', 'text'], ['kind', 'text']);
      return { kind, text: text(a['text'], `${field}.text`, 512) };
    }
    case 'choice': {
      const a = object(value, field, ['kind', 'choiceId'], ['kind', 'choiceId']);
      return { kind, choiceId: id(a['choiceId'], `${field}.choiceId`) };
    }
    case 'tokens': {
      const a = object(value, field, ['kind', 'tokenIds'], ['kind', 'tokenIds']);
      const list = a['tokenIds'];
      if (!Array.isArray(list) || list.length > 40) fail(`${field}.tokenIds`);
      return { kind, tokenIds: list.map((t, i) => id(t, `${field}.tokenIds[${i}]`)) };
    }
    case 'pairs': {
      const a = object(value, field, ['kind', 'matches'], ['kind', 'matches']);
      const list = a['matches'];
      if (!Array.isArray(list) || list.length > 10) fail(`${field}.matches`);
      return {
        kind,
        matches: list.map((m, i) => {
          const match = object(
            m,
            `${field}.matches[${i}]`,
            ['leftId', 'rightId'],
            ['leftId', 'rightId'],
          );
          return {
            leftId: id(match['leftId'], 'leftId'),
            rightId: id(match['rightId'], 'rightId'),
          };
        }),
      };
    }
    case 'speech': {
      const a = object(value, field, ['kind', 'assessmentJobId'], ['kind', 'assessmentJobId']);
      return { kind, assessmentJobId: id(a['assessmentJobId'], `${field}.assessmentJobId`) };
    }
    default:
      return fail(`${field}.kind`);
  }
}

/** Query string -> map; rejects unknown or duplicate keys. */
export function query(raw: string, allowed: readonly string[]): Record<string, string> {
  const out: Record<string, string> = {};
  const params = new URLSearchParams(raw.startsWith('?') ? raw.slice(1) : raw);
  for (const [key, value] of params) {
    if (!allowed.includes(key) || key in out) fail(`query.${key}`, 'UNKNOWN_OR_DUPLICATE');
    out[key] = value;
  }
  return out;
}
export function limitOf(q: Record<string, string>, fallback = 20): number {
  if (q['limit'] === undefined) return fallback;
  const n = Number(q['limit']);
  return Number.isInteger(n) && n >= 1 && n <= 100 ? n : fail('limit');
}
export function cursorOf(q: Record<string, string>): string | undefined {
  const c = q['cursor'];
  if (c !== undefined && (c.length > 256 || !c)) fail('cursor');
  return c;
}

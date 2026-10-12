// Strict request validation for AI operations (OpenAPI request schemas; unknown fields rejected).
// Small hand-written checks keep the hosted bundle free of a schema engine.
import { ServiceError } from '../../../shared/src/errors.js';

const ID = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SHA = /^[a-f0-9]{64}$/;

export function fail(field: string, reason = 'INVALID'): never {
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
export const uuid = (value: unknown, field: string): string =>
  typeof value === 'string' && UUID.test(value) ? value.toLowerCase() : fail(field);
export const sha = (value: unknown, field: string): string =>
  typeof value === 'string' && SHA.test(value) ? value : fail(field);
export const int = (value: unknown, field: string, min: number, max: number): number =>
  Number.isInteger(value) && (value as number) >= min && (value as number) <= max
    ? (value as number)
    : fail(field);
export function oneOf<T extends string>(value: unknown, field: string, values: readonly T[]): T {
  return typeof value === 'string' && (values as readonly string[]).includes(value)
    ? (value as T)
    : fail(field);
}
export function text(value: unknown, field: string, min: number, max: number): string {
  return typeof value === 'string' && value.length >= min && value.length <= max
    ? value
    : fail(field);
}
export const nullableId = (value: unknown, field: string): string | null =>
  value === null || value === undefined ? null : id(value, field);

/** Parse a query string allowing only the listed keys (each at most once). */
export function query(raw: string, allowed: readonly string[]): Record<string, string> {
  const out: Record<string, string> = {};
  if (!raw) return out;
  for (const [key, value] of new URLSearchParams(raw)) {
    if (!allowed.includes(key)) fail(key, 'UNKNOWN_QUERY');
    if (key in out) fail(key, 'DUPLICATE_QUERY');
    out[key] = value;
  }
  return out;
}

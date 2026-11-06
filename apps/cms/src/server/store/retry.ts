import { AppwriteException } from 'node-appwrite';
import { StoreUnavailableError } from './port';

const ATTEMPTS = 3;
const BACKOFF_MS = 400;

export function statusOf(error: unknown): number | undefined {
  return error instanceof AppwriteException ? error.code : (error as { code?: number })?.code;
}

/**
 * Retry what the network broke: no HTTP status at all (the socket died before an answer) or the region
 * said 429/5xx. A 4xx is about our own request and a plain exception is our own bug, so neither is
 * worth another round trip.
 */
export function isTransient(error: unknown): boolean {
  const status = statusOf(error);
  if (status !== undefined) return status === 429 || status >= 500;
  const code = (error as { cause?: { code?: string } } | undefined)?.cause?.code;
  return typeof code === 'string';
}

const wait = (ms: number): Promise<void> => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * The hosted endpoint drops a connection now and then, and a save the admin already clicked is worth
 * two more attempts. When the store really is unreachable they get one honest sentence back instead of
 * a 500 that leaves the button spinning forever.
 */
export async function withTransientRetry<T>(request: () => Promise<T>): Promise<T> {
  let last: unknown;
  for (let attempt = 1; attempt <= ATTEMPTS; attempt += 1) {
    try {
      return await request();
    } catch (error) {
      if (!isTransient(error)) throw error;
      last = error;
      if (attempt < ATTEMPTS) await wait(BACKOFF_MS * attempt);
    }
  }
  throw new StoreUnavailableError(undefined, last);
}

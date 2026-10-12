// Verified-subject auth port (docs/api/AUTH.md). The router depends only on AuthPort;
// the hosted adapter wraps createAccountVerifier (Account.get), tests inject a fake.
import { ServiceError } from './errors.js';

export interface VerifiedSubject {
  userId: string;
}
export interface AuthPort {
  verify(jwt: string): Promise<VerifiedSubject>;
}

const BEARER = /^Bearer ([A-Za-z0-9._~+/=-]{1,8192})$/i;

/**
 * Read the credential from Authorization: Bearer or the Appwrite direct-execution
 * x-appwrite-user-jwt header. Caller-supplied user-id headers are never consulted.
 */
export function extractJwt(headers: Record<string, string | undefined>): string {
  const authorization = headers['authorization'];
  const direct = headers['x-appwrite-user-jwt'];
  let bearer: string | undefined;
  if (authorization !== undefined) {
    const match = BEARER.exec(authorization.trim());
    if (!match?.[1]) throw new ServiceError('AUTH_REQUIRED');
    bearer = match[1];
  }
  if (bearer && direct && bearer !== direct) throw new ServiceError('AUTH_REQUIRED');
  const jwt = bearer ?? direct;
  if (!jwt || jwt.length > 8192) throw new ServiceError('AUTH_REQUIRED');
  return jwt;
}

export interface AppwriteAuthPortOptions {
  /** Account.get deadline per attempt (SERVICE_CATALOG: 2s). */
  deadlineMs?: number;
  /** One retry only for transport/5xx failures. */
  retries?: number;
  sleep?: (ms: number) => Promise<void>;
}

function classify(error: unknown): 'required' | 'expired' | 'blocked' | 'transient' {
  if (error instanceof ServiceError) {
    return error.code === 'AUTH_REQUIRED' ? 'required' : 'transient';
  }
  const value = error as { message?: unknown; code?: unknown; type?: unknown } | null;
  if (value?.message === 'AUTH_REQUIRED') return 'required';
  const code = typeof value?.code === 'number' ? value.code : undefined;
  if (code === undefined || code >= 500 || code === 408 || code === 429) return 'transient';
  if (value?.type === 'user_blocked') return 'blocked';
  return 'expired';
}

function withDeadline<T>(work: Promise<T>, ms: number): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new ServiceError('AUTH_UNAVAILABLE')), ms);
  });
  return Promise.race([work, timeout]).finally(() => clearTimeout(timer));
}

/** Fail-closed adapter around an Account.get verifier (see verify-jwt.ts). */
export function createAppwriteAuthPort(
  verifyAccount: (jwt: string) => Promise<string>,
  options: AppwriteAuthPortOptions = {},
): AuthPort {
  const deadlineMs = options.deadlineMs ?? 2000;
  const retries = Math.min(options.retries ?? 1, 1);
  const sleep = options.sleep ?? ((ms) => new Promise((resolve) => setTimeout(resolve, ms)));
  return {
    async verify(jwt) {
      for (let attempt = 0; ; attempt++) {
        try {
          const userId = await withDeadline(verifyAccount(jwt), deadlineMs);
          if (typeof userId !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/.test(userId)) {
            throw new ServiceError('AUTH_UNAVAILABLE');
          }
          return { userId };
        } catch (error) {
          const kind = classify(error);
          if (kind === 'required') throw new ServiceError('AUTH_REQUIRED');
          if (kind === 'expired') throw new ServiceError('AUTH_EXPIRED');
          if (kind === 'blocked') throw new ServiceError('ACCOUNT_BLOCKED');
          if (attempt >= retries) throw new ServiceError('AUTH_UNAVAILABLE');
          await sleep(100);
        }
      }
    },
  };
}

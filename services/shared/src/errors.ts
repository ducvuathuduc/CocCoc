// Standard error envelope and code table from docs/api/EVENTS_ERRORS.md.
// SERVICE_NOT_CONFIGURED is the scaffold's fail-closed 503 code (documented in EVENTS_ERRORS.md).
const CODE_STATUS = {
  VALIDATION_ERROR: 400,
  UNKNOWN_EXERCISE_TYPE: 400,
  INVALID_AUDIO: 400,
  INVALID_TIMEZONE: 400,
  MODE_UNAVAILABLE: 400,
  AUTH_REQUIRED: 401,
  AUTH_EXPIRED: 401,
  FORBIDDEN: 403,
  ACCOUNT_BLOCKED: 403,
  MAINTAINER_REQUIRED: 403,
  ENTITLEMENT_REQUIRED: 403,
  USER_BLOCKED: 403,
  AD_NOT_ELIGIBLE: 403,
  NOT_FOUND: 404,
  PROFILE_UNAVAILABLE: 404,
  CLASSROOM_CODE_INVALID: 404,
  ACTIVITY_NOT_FOUND: 404,
  NODE_LOCKED: 409,
  SESSION_CONFLICT: 409,
  SESSION_INCOMPLETE: 409,
  SESSION_EXPIRED: 409,
  CONTENT_VERSION_RETIRED: 409,
  IDEMPOTENCY_CONFLICT: 409,
  REVISION_CONFLICT: 409,
  INSUFFICIENT_GEMS: 409,
  FREEZE_CAPACITY: 409,
  CHECKPOINT_LOCKED: 409,
  ENERGY_DEPLETED: 409,
  FRIEND_STREAK_LIMIT: 409,
  ITEM_UNAVAILABLE: 409,
  STREAK_REPAIR_EXPIRED: 409,
  PURCHASE_PENDING: 409,
  PROMO_ALREADY_REDEEMED: 409,
  AD_DAILY_CAP: 409,
  ACTIVE_VOICE_SESSION: 409,
  VOICE_RESERVATION_CONFLICT: 409,
  VOICE_SESSION_EXPIRED: 409,
  VOICE_EPOCH_CONFLICT: 409,
  VOICE_TOKEN_DELIVERY_UNCERTAIN: 409,
  PAYLOAD_TOO_LARGE: 413,
  RATE_LIMITED: 429,
  QUOTA_EXHAUSTED: 429,
  INTERNAL_ERROR: 500,
  AUTH_UNAVAILABLE: 503,
  DB_UNAVAILABLE: 503,
  STORAGE_UNAVAILABLE: 503,
  AI_PROVIDER_UNAVAILABLE: 503,
  ASSESSMENT_UNAVAILABLE: 503,
  OPPONENT_UNAVAILABLE: 503,
  NATIVE_LIVE_DISABLED: 503,
  SERVICE_NOT_CONFIGURED: 503,
  DEADLINE_EXCEEDED: 504,
} as const;
export type ErrorCode = keyof typeof CODE_STATUS;
export const ERROR_CODES = Object.keys(CODE_STATUS) as ErrorCode[];

// Bounded transient retry is allowed for 429/503/504 except where the table forbids it.
const NOT_RETRYABLE = new Set<ErrorCode>(['NATIVE_LIVE_DISABLED', 'SERVICE_NOT_CONFIGURED']);
const DEFAULT_MESSAGES: Partial<Record<ErrorCode, string>> = {
  VALIDATION_ERROR: 'The request is invalid.',
  AUTH_REQUIRED: 'Authentication required.',
  AUTH_EXPIRED: 'Session expired. Sign in again.',
  FORBIDDEN: 'This resource is not accessible.',
  ACCOUNT_BLOCKED: 'This resource is not accessible.',
  NOT_FOUND: 'Not found.',
  IDEMPOTENCY_CONFLICT: 'This operation key was already used with a different request.',
  PAYLOAD_TOO_LARGE: 'The request is too large.',
  INTERNAL_ERROR: 'An internal error occurred.',
  AUTH_UNAVAILABLE: 'Authentication is temporarily unavailable.',
  DB_UNAVAILABLE: 'Storage is temporarily unavailable.',
  MODE_UNAVAILABLE: 'This content does not support the requested session mode.',
  ACTIVITY_NOT_FOUND: 'This activity is not available.',
  CHECKPOINT_LOCKED: 'Complete the section prerequisites first.',
  OPPONENT_UNAVAILABLE: 'The scripted opponent is unavailable.',
  SERVICE_NOT_CONFIGURED: 'This service has no enabled business adapter.',
  DEADLINE_EXCEEDED: 'The request deadline was exceeded.',
};

export function statusFor(code: ErrorCode): number {
  return CODE_STATUS[code];
}
export function isRetryable(code: ErrorCode): boolean {
  const status = CODE_STATUS[code];
  return (status === 429 || status === 503 || status === 504) && !NOT_RETRYABLE.has(code);
}

export class ServiceError extends Error {
  readonly code: ErrorCode;
  readonly details: Record<string, unknown>;
  readonly retryAfterSeconds: number | undefined;
  constructor(
    code: ErrorCode,
    options: {
      message?: string;
      details?: Record<string, unknown>;
      retryAfterSeconds?: number;
    } = {},
  ) {
    super(options.message ?? DEFAULT_MESSAGES[code] ?? code);
    this.name = 'ServiceError';
    this.code = code;
    this.details = options.details ?? {};
    this.retryAfterSeconds = options.retryAfterSeconds;
  }
}

export interface ErrorEnvelope {
  error: {
    code: ErrorCode;
    message: string;
    requestId: string;
    details: Record<string, unknown>;
    retryable: boolean;
  };
}

/** Map any thrown value to a redacted envelope; unknown errors never leak their message. */
export function toErrorResponse(
  error: unknown,
  requestId: string,
): { status: number; body: ErrorEnvelope; retryAfterSeconds: number | undefined } {
  const known = error instanceof ServiceError ? error : new ServiceError('INTERNAL_ERROR');
  return {
    status: statusFor(known.code),
    retryAfterSeconds: known.retryAfterSeconds,
    body: {
      error: {
        code: known.code,
        message: known.message.slice(0, 256),
        requestId,
        details: known.details,
        retryable: isRetryable(known.code),
      },
    },
  };
}

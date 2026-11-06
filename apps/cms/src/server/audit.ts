import { config } from './config';
import { getStore } from './store';
import { StoreUnavailableError } from './store/port';

export interface AuditInput {
  actorId: string;
  operation: string;
  targetId: string;
  beforeJson?: string;
  afterJson?: string;
}

/**
 * Records who changed what and returns a warning instead of throwing when the link dropped: by then the
 * content row is already written, and answering "not saved" would make the admin repeat a save that
 * happened. Anything else (a schema rejection) must still surface.
 */
export async function recordAudit(input: AuditInput): Promise<string | null> {
  const store = getStore();
  try {
    await store.appendAudit({
      entryId: crypto.randomUUID(),
      actorId: input.actorId,
      operation: input.operation,
      targetId: input.targetId,
      beforeJson: input.beforeJson ?? '',
      afterJson: input.afterJson ?? '',
      requestId: crypto.randomUUID(),
      createdAt: new Date().toISOString(),
    });
    return null;
  } catch (error) {
    if (error instanceof StoreUnavailableError)
      return 'Đã lưu nội dung, nhưng nhật ký thao tác không ghi được. Kiểm tra lại khi mạng ổn định.';
    throw error;
  }
}

/** Exported pages use this to tell the maintainer which store they are actually looking at. */
export function storeLabel(): string {
  return config().mode === 'appwrite' ? 'Appwrite' : 'File (dev)';
}

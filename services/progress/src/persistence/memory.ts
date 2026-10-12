// LOCAL TEST ADAPTER ONLY — never imported by src/index.ts or any hosted artifact.
import { createMemoryOwnerStore } from '../../../shared/src/testing/memory-owner-store.js';
import { PROGRESS_TABLES } from './port.js';

export function createMemoryProgressPersistence(nowMs?: () => number) {
  return createMemoryOwnerStore('progress', PROGRESS_TABLES, nowMs);
}

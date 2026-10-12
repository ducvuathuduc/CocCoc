// LOCAL TEST ADAPTER ONLY — never imported by src/index.ts or any hosted artifact.
import { createMemoryOwnerStore } from '../../../shared/src/testing/memory-owner-store.js';
import { AI_TABLES } from './port.js';

export function createMemoryAiPersistence(nowMs?: () => number) {
  return createMemoryOwnerStore('ai', AI_TABLES, nowMs);
}

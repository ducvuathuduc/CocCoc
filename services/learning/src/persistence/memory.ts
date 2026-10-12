// LOCAL TEST ADAPTER ONLY — never imported by src/index.ts or any hosted artifact.
import { createMemoryOwnerStore } from '../../../shared/src/testing/memory-owner-store.js';
import { LEARNING_TABLES } from './port.js';

export function createMemoryLearningPersistence(nowMs?: () => number) {
  return createMemoryOwnerStore('learning', LEARNING_TABLES, nowMs);
}

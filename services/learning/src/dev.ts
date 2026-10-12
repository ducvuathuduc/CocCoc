// LOCAL DEV composition root for `pnpm dev:services`. Same wiring as the hosted entrypoint, but
// with the explicit in-memory adapter, the committed seed content (content/*/dist, dev-signed and
// published at startup through the real publish use case) and mode 'local-dev'.
// Optional, local only:
//   COC_DEV_AUTH=1        accept `Authorization: Bearer dev-<userId>` (never in hosted code)
//   COC_DEV_RELAY=0       disable signed delivery of lesson.completed.v1 to the Progress dev server
import { randomUUID } from 'node:crypto';
import { ServiceError } from '../../shared/src/errors.js';
import type { AuthPort } from '../../shared/src/auth.js';
import type { Keyring } from '../../shared/src/service-hmac.js';
import { createRouter, type FunctionContext } from '../../shared/src/transport.js';
import { publishContent } from './application/content.js';
import type { LearningDeps } from './application/deps.js';
import { dispatchOutbox } from './application/outbox.js';
import { createImmediateRelay, httpDeliver } from './application/relay.js';
import { createContentRepository } from './content/repository.js';
import { learningHandler, learningWiring } from './http/wiring.js';
import { createMemoryLearningPersistence } from './persistence/memory.js';
import { devContentKeyring } from './testing/dev-content-key.js';
import { loadLocalContent } from './testing/local-content.js';

const DEV_TOKEN = /^dev-([A-Za-z0-9][A-Za-z0-9_.-]{0,35})$/;
export const devAuth: AuthPort = {
  async verify(jwt) {
    const match = DEV_TOKEN.exec(jwt);
    if (!match?.[1]) throw new ServiceError('AUTH_REQUIRED');
    return { userId: match[1] };
  },
};

export function createDevHandler(
  keyring: Keyring,
  env: Record<string, string | undefined> = process.env,
) {
  const persistence = createMemoryLearningPersistence();
  const local = loadLocalContent(env['COC_REPO_ROOT'] ?? process.cwd());
  const deps: LearningDeps = {
    persistence,
    content: createContentRepository({
      persistence,
      files: local.files,
      keyring: devContentKeyring(),
    }),
    nowMs: Date.now,
    newId: randomUUID,
    maintainers: new Set(['dev-maintainer']),
  };
  const ownKey = [...keyring.values()].find((k) => k.sender === 'learning');
  const progressPort = Number(env['COC_DEV_PORT_BASE'] ?? 4101) + 1;
  if (ownKey && env['COC_DEV_RELAY'] !== '0') {
    const deliver = httpDeliver({
      key: ownKey,
      progressBaseUrl: `http://127.0.0.1:${progressPort}`,
    });
    deps.relay = createImmediateRelay(() => deps, deliver);
    // Backstop sweep for anything the immediate relay could not deliver.
    setInterval(() => void dispatchOutbox(deps, deliver).catch(() => undefined), 5000).unref();
  }
  const seeded = (async () => {
    for (const p of local.publications) {
      await publishContent(
        deps,
        'dev-maintainer',
        { ...p, expectedPublishedVersion: (await currentVersion(p.courseId)) ?? null },
        randomUUID(),
        `seed:${p.courseId}:${p.versionId}`,
        'dev-seed',
        { system: true },
      );
    }
  })();
  async function currentVersion(courseId: string): Promise<string | null> {
    const page = await persistence.list('l_courses', { equal: { courseId }, limit: 1 });
    return page.items[0] ? String(page.items[0].row['publishedVersion']) : null;
  }
  const router = createRouter({
    service: 'learning',
    persistence,
    mode: 'local-dev',
    keyring,
    buildId: 'local-dev',
    ...(env['COC_DEV_AUTH'] === '1' ? { auth: devAuth } : {}),
    ...learningWiring(deps),
  });
  const scoped = learningHandler(router, deps);
  const handler = async (context: FunctionContext) => {
    await seeded;
    return scoped(context);
  };
  return { handler, persistence, deps, seeded };
}

// The identity test double a harness aliases over '@/server/auth-core'. Only the Appwrite account
// lookup is faked: session.ts, config() and the real isAdmin() still decide who may act, so an
// action check drives the same access rule as the deployed CMS — and no CMS build ships a shortcut.
export const HARNESS_ADMIN_SECRET = 'sess-harness-admin';
export const HARNESS_OUTSIDER_SECRET = 'sess-harness-outsider';

export function authCoreStub() {
  return (
    'export async function resolveIdentity(secret) {\n' +
    '  const owners = {\n' +
    `    ${JSON.stringify(HARNESS_ADMIN_SECRET)}: listedAdminId(),\n` +
    `    ${JSON.stringify(HARNESS_OUTSIDER_SECRET)}: 'someone-else',\n` +
    '  };\n' +
    "  const userId = owners[secret ?? ''];\n" +
    '  if (!userId) return null;\n' +
    "  return { userId, email: userId + '@harness.local', name: userId };\n" +
    '}\n' +
    'function listedAdminId() {\n' +
    "  return (process.env.CMS_ADMIN_USER_IDS ?? '').split(',')[0]?.trim() ?? '';\n" +
    '}\n'
  );
}

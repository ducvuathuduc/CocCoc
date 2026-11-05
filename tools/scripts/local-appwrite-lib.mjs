export function assertLocalKeys(keys) {
  if (
    !keys ||
    !['setup', 'learning', 'progress', 'ai'].every(
      (owner) =>
        typeof keys[owner] === 'string' &&
        keys[owner].length > 0 &&
        !['undefined', 'null'].includes(keys[owner]),
    )
  ) {
    throw new Error('INCOMPLETE_LOCAL_KEYS: finish bootstrap before admission');
  }
}

export function validLocalReceipt(receipt, expected, now = Date.now()) {
  return Boolean(
    receipt &&
    receipt.status === 'passed' &&
    Number.isSafeInteger(receipt.at) &&
    receipt.at >= 0 &&
    receipt.at <= now &&
    now - receipt.at <= 3_600_000 &&
    ['endpoint', 'project', 'fingerprint'].every((key) => receipt[key] === expected[key]),
  );
}

// Console GET returns the same secret, so a crash after POST is recoverable without rotation.
export async function ensureLocalKey({ request, project, owner, headers, scopes }) {
  const base = `/organization/projects/${project}/keys`;
  const keyId = `${owner}-local`;
  const existing = await request('GET', `${base}/${keyId}`, undefined, headers, [404]);
  const result =
    existing.response.status === 404
      ? await request('POST', base, { keyId, name: `Local ${owner}`, scopes }, headers)
      : await request('PUT', `${base}/${keyId}`, { name: `Local ${owner}`, scopes }, headers);
  const secret = result.data.secret;
  if (typeof secret !== 'string' || !secret) throw new Error('Local key response missing secret');
  return secret;
}

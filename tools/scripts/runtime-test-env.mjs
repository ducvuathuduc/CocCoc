// Deliberately allow only OS process essentials into disposable smoke children.
// Inheriting the caller's environment could turn a local test into a cloud job.
export function disposableRuntimeEnv(overrides = {}, source = process.env) {
  const names = new Set([
    'path',
    'systemroot',
    'windir',
    'comspec',
    'pathext',
    'temp',
    'tmp',
    'tmpdir',
    'home',
    'userprofile',
    'lang',
    'lc_all',
  ]);
  return {
    ...Object.fromEntries(
      Object.entries(source).filter(
        ([name, value]) => names.has(name.toLowerCase()) && typeof value === 'string',
      ),
    ),
    ...overrides,
  };
}

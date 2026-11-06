import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');
const source = read('docs/api/openapi.yaml');
const spec = JSON.parse(source);
const q = (s) => JSON.stringify(s);
const operations = Object.entries(spec.paths).flatMap(([p, item]) =>
  Object.entries(item)
    .filter(([, op]) => op.operationId)
    .map(([method, op]) => {
      const parameters = (op.parameters ?? []).map((v) =>
        v.$ref ? spec.components.parameters[v.$ref.split('/').at(-1)] : v,
      );
      return {
        operationId: op.operationId,
        owner: op['x-owner'],
        method: method.toUpperCase(),
        path: p,
        queryKeys: parameters.filter((v) => v.in === 'query').map((v) => v.name),
        requestSchema:
          op.requestBody?.content?.['application/json']?.schema?.$ref?.split('/').at(-1) ?? null,
        responseSchema:
          Object.entries(op.responses)
            .find(([code]) => /^2/.test(code))?.[1]
            ?.content?.['application/json']?.schema?.$ref?.split('/')
            .at(-1) ?? null,
      };
    }),
);
const catalog = `// Generated from docs/api/openapi.yaml. Run node backend-dotnet/tools/generate-contracts.mjs.\nnamespace CocEnglish.Contracts;\n\npublic sealed record ContractOperation(string OperationId, string Owner, string Method, string Path, string[] QueryKeys, string? RequestSchema, string? ResponseSchema);\n\npublic static class RouteCatalog\n{\n    public const string SourceSha256 = ${q(crypto.createHash('sha256').update(source).digest('hex'))};\n    public static IReadOnlyList<ContractOperation> All { get; } =\n    [\n${operations.map((o) => `        new(${q(o.operationId)}, ${q(o.owner)}, ${q(o.method)}, ${q(o.path)}, [${o.queryKeys.map(q).join(', ')}], ${q(o.requestSchema)}, ${q(o.responseSchema)}),`).join('\n')}\n    ];\n}\n`;
const errors = read('services/shared/src/errors.ts');
const statuses = [...errors.split('} as const;')[0].matchAll(/^  ([A-Z_]+): (\d+),/gm)];
const messages = [
  ...errors
    .slice(errors.indexOf('const DEFAULT_MESSAGES'))
    .split('\n};')[0]
    .matchAll(/^  ([A-Z_]+): '([^']*)',/gm),
];
const errorCatalog = `// Generated from services/shared/src/errors.ts; retain the Node wire contract.\nnamespace CocEnglish.Contracts;\n\npublic static class ErrorCatalog\n{\n    public static IReadOnlyDictionary<string, int> StatusCodes { get; } = new Dictionary<string, int>(StringComparer.Ordinal)\n    {\n${statuses.map(([, code, status]) => `        [${q(code)}] = ${status},`).join('\n')}\n    };\n    public static IReadOnlyDictionary<string, string> Messages { get; } = new Dictionary<string, string>(StringComparer.Ordinal)\n    {\n${messages.map(([, code, text]) => `        [${q(code)}] = ${q(text)},`).join('\n')}\n    };\n}\n`;
for (const [name, rawContent] of Object.entries({
  'RouteCatalog.generated.cs': catalog,
  'ErrorCatalog.generated.cs': errorCatalog,
})) {
  const content = '#nullable enable\n' + rawContent;
  const target = path.join(root, 'backend-dotnet/src/CocEnglish.Contracts', name);
  if (process.argv.includes('--check')) {
    if (!fs.existsSync(target) || fs.readFileSync(target, 'utf8') !== content)
      throw new Error(`Stale .NET contract: ${name}`);
  } else fs.writeFileSync(target, content);
}
console.log(
  JSON.stringify({
    status: 'PASS',
    operations: operations.length,
    errors: statuses.length,
    mode: process.argv.includes('--check') ? 'check' : 'generate',
  }),
);

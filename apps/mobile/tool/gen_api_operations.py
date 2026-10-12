#!/usr/bin/env python3
"""Generate lib/core/api/client/api_operations.g.dart from docs/api/openapi.yaml.

Only client-callable operations (Appwrite JWT security) are emitted; internal
service-signature and admin routes are skipped. Run from apps/mobile:
    python3 tool/gen_api_operations.py
test/core/api/api_operations_sync_test.dart fails when the output drifts.
"""
import hashlib, json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
SPEC = ROOT / 'docs/api/openapi.yaml'
OUT = pathlib.Path(__file__).resolve().parents[1] / 'lib/core/api/client/api_operations.g.dart'

def main():
    raw = SPEC.read_bytes()
    spec = json.loads(raw)
    params = spec['components']['parameters']
    ops = []
    for path, item in spec['paths'].items():
        for method, op in item.items():
            if method not in ('get', 'post', 'put', 'patch', 'delete'):
                continue
            sec = op.get('security', spec.get('security', []))
            names = {k for s in sec for k in s}
            if 'appwriteJWT' not in names or path.startswith('/internal') or path.startswith('/v1/admin'):
                continue
            idem = False
            for p in op.get('parameters', []):
                p = params[p['$ref'].split('/')[-1]] if '$ref' in p else p
                if p.get('name') == 'Idempotency-Key' and p.get('in') == 'header':
                    idem = True
            ops.append((op['operationId'], method.upper(), path, op.get('x-owner', 'learning'), idem))
    ops.sort()
    sha = hashlib.sha256(raw).hexdigest()
    lines = [
        '// GENERATED CODE - DO NOT EDIT BY HAND.',
        f'// Source: docs/api/openapi.yaml (sha256 {sha}).',
        '// Generator: apps/mobile/tool/gen_api_operations.py',
        '',
        "import 'api_operation.dart';",
        '',
        '/// Client-callable OpenAPI operations (Appwrite JWT), keyed by operationId.',
        'abstract final class ApiOperations {',
    ]
    for oid, m, p, owner, idem in ops:
        lines.append(f"  static const {oid} = ApiOperation('{oid}', '{m}', '{p}', ApiService.{owner}, idempotent: {'true' if idem else 'false'});")
    lines.append('')
    lines.append('  static const all = <ApiOperation>[')
    for oid, *_ in ops:
        lines.append(f'    {oid},')
    lines.append('  ];')
    lines.append('}')
    text = '\n'.join(lines) + '\n'
    if '--check' in sys.argv:
        sys.exit(0 if OUT.exists() and OUT.read_text() == text else 1)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text)
    print(f'wrote {len(ops)} operations -> {OUT}')

main()

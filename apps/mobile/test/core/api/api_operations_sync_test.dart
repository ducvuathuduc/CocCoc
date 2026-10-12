// The client operation table must match docs/api/openapi.yaml exactly
// (regenerate with `python3 tool/gen_api_operations.py`).
import 'dart:convert';
import 'dart:io';

import 'package:cocenglish/core/api/client/api_operations.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiOperations mirrors every client-callable OpenAPI operation', () {
    final spec = jsonDecode(
      File('../../docs/api/openapi.yaml').readAsStringSync(),
    ) as Map<String, Object?>;
    final params =
        (spec['components']! as Map)['parameters']! as Map<String, Object?>;
    final expected = <String, String>{};
    final paths = spec['paths']! as Map<String, Object?>;
    for (final entry in paths.entries) {
      final item = entry.value! as Map<String, Object?>;
      for (final method in ['get', 'post', 'put', 'patch', 'delete']) {
        final op = item[method] as Map<String, Object?>?;
        if (op == null) continue;
        final security = (op['security'] as List<Object?>? ?? const [])
            .expand((s) => (s! as Map).keys)
            .toSet();
        if (!security.contains('appwriteJWT') ||
            entry.key.startsWith('/internal') ||
            entry.key.startsWith('/v1/admin')) {
          continue;
        }
        var idempotent = false;
        for (final raw in (op['parameters'] as List<Object?>? ?? const [])) {
          var p = raw! as Map<String, Object?>;
          if (p[r'$ref'] case final String ref) {
            p = params[ref.split('/').last]! as Map<String, Object?>;
          }
          if (p['name'] == 'Idempotency-Key' && p['in'] == 'header') {
            idempotent = true;
          }
        }
        expected[op['operationId']! as String] =
            '${method.toUpperCase()} ${entry.key} ${op['x-owner']} $idempotent';
      }
    }
    final actual = {
      for (final op in ApiOperations.all)
        op.operationId:
            '${op.method} ${op.pathTemplate} ${op.service.name} ${op.idempotent}',
    };
    expect(actual, expected);
  });
}

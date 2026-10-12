/// Backend service that owns an operation (OpenAPI `x-owner`).
enum ApiService { learning, progress, ai }

/// One client-callable OpenAPI operation.
final class ApiOperation {
  const ApiOperation(
    this.operationId,
    this.method,
    this.pathTemplate,
    this.service, {
    required this.idempotent,
  });

  final String operationId;
  final String method;

  /// Path with `{param}` placeholders, exactly as declared in OpenAPI.
  final String pathTemplate;
  final ApiService service;

  /// Whether the operation requires an `Idempotency-Key` header.
  final bool idempotent;

  /// Expands `{param}` placeholders with URI-encoded values.
  String path(Map<String, String> params) {
    return pathTemplate.replaceAllMapped(RegExp(r'\{([A-Za-z0-9_]+)\}'), (m) {
      final name = m.group(1)!;
      final value = params[name];
      if (value == null || value.isEmpty) {
        throw ArgumentError.value(params, 'params', 'Missing path param $name');
      }
      return Uri.encodeComponent(value);
    });
  }

  @override
  String toString() => '$method $pathTemplate ($operationId)';
}

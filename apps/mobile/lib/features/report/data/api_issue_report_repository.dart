import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/service_apis.dart';
import '../domain/issue_report.dart';
import 'issue_report_repository.dart';

/// Sends the existing report menu to the Learning owner without blocking a lesson.
class ApiIssueReportRepository implements IssueReportRepository {
  ApiIssueReportRepository(
    this.api, {
    required this.lessonVersion,
    this.isCurrent,
  });

  final LearningApi api;
  final String? Function() lessonVersion;
  final bool Function()? isCurrent;

  @override
  final content = const IssueReportContent();

  String? _pendingIdentity;
  String? _pendingKey;
  Future<bool>? _inFlight;

  @override
  Future<bool> submit(IssueReport report) {
    final version = lessonVersion();
    final category = switch (report.category) {
      'The audio does not sound correct.' || 'The audio is missing.' => 'AUDIO',
      'My answer should not have been accepted.' => 'ANSWER',
      'The hints are wrong.' ||
      'The hints are missing.' ||
      'An image does not look quite right.' ||
      'An image is missing.' ||
      'There’s an issue with the English meaning.' => 'CONTENT',
      'Something else went wrong.' => 'OTHER',
      _ => null,
    };
    final validId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$');
    if ((isCurrent != null && !isCurrent!()) ||
        version == null ||
        !validId.hasMatch(version) ||
        !validId.hasMatch(report.exerciseId) ||
        category == null) {
      return Future.value(false);
    }
    final identity =
        '${report.exerciseId}\u0000$version\u0000${report.category}';
    if (_inFlight != null) {
      return identity == _pendingIdentity ? _inFlight! : Future.value(false);
    }
    if (identity != _pendingIdentity) {
      _pendingIdentity = identity;
      _pendingKey = api.client.ids.next();
    }
    final key = _pendingKey!;
    final operation = _send(report, version, category, key);
    _inFlight = operation;
    return operation.whenComplete(() => _inFlight = null);
  }

  Future<bool> _send(
    IssueReport report,
    String version,
    String category,
    String key,
  ) async {
    try {
      final receipt = await api.createReport(
        wire.ReportRequest(
          exerciseId: report.exerciseId,
          lessonVersion: version,
          category: category,
          note: report.category,
        ),
        idempotencyKey: key,
      );
      if ((isCurrent != null && !isCurrent!()) ||
          receipt.operationId != key ||
          (receipt.status != 'accepted' && receipt.status != 'replayed')) {
        return false;
      }
      _pendingIdentity = null;
      _pendingKey = null;
      return true;
    } catch (_) {
      return false;
    }
  }
}

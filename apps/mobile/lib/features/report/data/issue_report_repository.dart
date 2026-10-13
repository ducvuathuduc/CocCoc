import '../domain/issue_report.dart';

/// No issue-report API contract exists yet; the mock keeps reports in memory
/// so the UI can be exercised end to end.
abstract class IssueReportRepository {
  IssueReportContent get content;
  Future<bool> submit(IssueReport report);
}

class MockIssueReportRepository implements IssueReportRepository {
  MockIssueReportRepository({
    this.content = const IssueReportContent(),
    this.succeed = true,
  });
  @override
  final IssueReportContent content;
  final bool succeed;
  final submitted = <IssueReport>[];
  @override
  Future<bool> submit(IssueReport report) async {
    if (!succeed) return false;
    submitted.add(report);
    return true;
  }
}

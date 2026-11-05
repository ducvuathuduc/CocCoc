import '../domain/issue_report.dart';

/// Reporting port shared by the Learning API and the local preview.
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

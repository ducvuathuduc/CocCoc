import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/issue_report_repository.dart';
import '../domain/issue_report.dart';

final issueReportRepositoryProvider = Provider<IssueReportRepository>(
  (ref) => MockIssueReportRepository(),
);
final issueReportContentProvider = Provider<IssueReportContent>(
  (ref) => ref.watch(issueReportRepositoryProvider).content,
);

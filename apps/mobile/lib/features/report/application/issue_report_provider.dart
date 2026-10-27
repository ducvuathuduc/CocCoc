import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import '../../auth/application/auth_controller.dart';
import '../../learning/application/learning_controller.dart';
import '../../learning/data/api_learning_repository.dart';
import '../data/api_issue_report_repository.dart';
import '../data/issue_report_repository.dart';
import '../domain/issue_report.dart';

final issueReportRepositoryProvider = Provider<IssueReportRepository>((ref) {
  if (!ref.watch(appConfigProvider).isApi) return MockIssueReportRepository();
  final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
  final learning = ref.watch(learningRepositoryProvider);
  return ApiIssueReportRepository(
    ref.watch(learningApiProvider),
    lessonVersion: () => learning is ApiLearningRepository
        ? learning.activeSession?.lessonVersion
        : null,
    isCurrent: () =>
        ref.mounted &&
        userId != null &&
        ref.read(authControllerProvider).user?.id == userId,
  );
});
final issueReportContentProvider = Provider<IssueReportContent>(
  (ref) => ref.watch(issueReportRepositoryProvider).content,
);

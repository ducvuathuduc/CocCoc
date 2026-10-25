import '../../../core/config/app_config.dart';
import '../../learning/domain/learning_models.dart';

/// The current wire contract has no score-unlock event. API mode must never
/// infer one from XP. Demo mode uses its already-claimed curriculum projection.
int? scoreUnlockForReceipt({
  required bool api,
  required String completionId,
  required SessionReceipt? receipt,
  required LearningState progress,
}) {
  if (api ||
      receipt == null ||
      receipt.id != completionId ||
      receipt.guest ||
      receipt.placement ||
      !receipt.firstCompletion ||
      receipt.rewardPending ||
      progress.completedLessons != 1 ||
      progress.score <= 0 ||
      !progress.claimedReceiptIds.contains(receipt.id)) {
    return null;
  }
  return progress.score;
}

/// Remembers which demo receipts have already shown their score celebration.
/// This is presentation state only; it never changes lesson rewards or progress.
class ScoreUnlockPresentationTracker {
  ScoreUnlockPresentationTracker({
    required AppConfig config,
    required String? accountId,
  }) : _api = config.isApi,
       lifecycleKey = '${config.dataSource.name}:${accountId ?? 'signed-out'}';

  final bool _api;
  final String lifecycleKey;
  final Set<String> _presentedReceiptIds = <String>{};

  int? take({
    required String completionId,
    required SessionReceipt? receipt,
    required LearningState progress,
  }) {
    final score = scoreUnlockForReceipt(
      api: _api,
      completionId: completionId,
      receipt: receipt,
      progress: progress,
    );
    if (score == null || !_presentedReceiptIds.add(completionId)) return null;
    return score;
  }
}

import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_exception.dart';
import '../../learning/data/learning_repository.dart';

abstract interface class AccountSyncRepository {
  Future<void> synchronize(String userId);
}

class ApiAccountSyncRepository implements AccountSyncRepository {
  const ApiAccountSyncRepository(this.learning, this.api);
  final OfflineLearningSync learning;
  final ApiEndpoints api;

  @override
  Future<void> synchronize(String userId) async {
    await learning.syncPending();
    // Direct reads prove connectivity/identity; a cached snapshot cannot certify
    // that the journal and authoritative reward state have converged.
    final profile = await api.getMe();
    if (profile.userId != userId) {
      throw const ApiException(
        code: 'FORBIDDEN',
        message: 'Identity mismatch.',
      );
    }
    await api.getRewards();
  }
}

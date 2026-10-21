import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/client/active_course.dart';
import '../../../core/config/app_config.dart';
import '../../auth/application/auth_controller.dart';
import '../data/notebook_repository.dart';
import '../domain/vocabulary_card.dart';

String notebookStorageKey(String mode, String? user, String course) =>
    'notebook.v1.${jsonEncode([mode, user, course])}';

final notebookStoreProvider = Provider.family<NotebookRepository, String>((
  ref,
  key,
) {
  final prefs = SharedPreferencesAsync();
  return NotebookRepository(
    read: () => prefs.getString(key),
    write: (value) => prefs.setString(key, value),
  );
});

final notebookRepositoryProvider = FutureProvider<NotebookRepository>((
  ref,
) async {
  final user = ref.watch(authControllerProvider.select((s) => s.user?.id));
  final config = ref.watch(appConfigProvider);
  final course = config.isApi
      ? await ref.watch(activeCourseProvider).id()
      : 'vi-en';
  return ref.watch(
    notebookStoreProvider(
      notebookStorageKey(config.isApi ? 'api' : 'demo', user, course),
    ),
  );
});
final notebookProvider =
    AsyncNotifierProvider<NotebookController, List<VocabularyCard>>(
      NotebookController.new,
    );

class NotebookController extends AsyncNotifier<List<VocabularyCard>> {
  @override
  Future<List<VocabularyCard>> build() async =>
      (await ref.watch(notebookRepositoryProvider.future)).load();
  Future<void> run(Future<void> Function(NotebookRepository) command) async {
    final source = ref.read(notebookRepositoryProvider.future);
    final repo = await source;
    if (!ref.mounted ||
        !identical(source, ref.read(notebookRepositoryProvider.future))) {
      throw StateError('Account changed. Reopen the notebook.');
    }
    await command(repo);
    // Invalidate the data provider so late results cannot replace a new user's state.
    if (ref.mounted &&
        identical(source, ref.read(notebookRepositoryProvider.future))) {
      ref.invalidateSelf();
    }
  }
}

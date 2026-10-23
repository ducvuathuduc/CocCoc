import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:cocenglish/features/vocabulary/application/notebook_controller.dart';
import 'package:cocenglish/features/vocabulary/data/notebook_repository.dart';
import 'package:cocenglish/features/vocabulary/domain/vocabulary_card.dart';

class TestAuth extends AuthController {
  @override
  AuthState build() => const AuthState();
  void account(String id) => state = state.copyWith(
    user: AuthUser(id: id, email: '$id@example.test', name: id),
  );
}

void main() {
  test(
    'account switch hides old cards and returning restores only owned cards',
    () async {
      final disk = <String, String>{};
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(TestAuth.new),
          notebookStoreProvider.overrideWith(
            (ref, key) => NotebookRepository(
              read: () async => disk[key],
              write: (value) async {
                disk[key] = value;
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(notebookProvider, (_, _) {});
      final auth = container.read(authControllerProvider.notifier) as TestAuth;
      auth.account('alice');
      await container.read(notebookProvider.future);
      await container
          .read(notebookProvider.notifier)
          .run(
            (r) => r.save(
              VocabularyCard.create('Hello', 'Xin chào', '', DateTime.now()),
            ),
          );
      expect(await container.read(notebookProvider.future), hasLength(1));
      auth.account('bob');
      expect(await container.read(notebookProvider.future), isEmpty);
      auth.account('alice');
      expect(
        (await container.read(notebookProvider.future)).single.term,
        'Hello',
      );
    },
  );
  test(
    'disposing while a durable write completes causes no late state mutation',
    () async {
      final gate = Completer<void>();
      final repo = NotebookRepository(
        read: () async => null,
        write: (_) => gate.future,
      );
      final container = ProviderContainer(
        overrides: [
          notebookRepositoryProvider.overrideWith((ref) async => repo),
        ],
      );
      container.listen(notebookProvider, (_, _) {});
      await container.read(notebookProvider.future);
      final work = container
          .read(notebookProvider.notifier)
          .run(
            (r) => r.save(
              VocabularyCard.create('Hello', 'Xin chào', '', DateTime.now()),
            ),
          );
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      gate.complete();
      await work;
    },
  );
}

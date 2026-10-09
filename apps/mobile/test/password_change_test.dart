import 'dart:async';

import 'package:cocenglish/features/account/application/password_change_controller.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/data/auth_repository.dart';
import 'package:cocenglish/features/auth/data/mock_auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'wrong old password preserves fields; valid retry changes mock login',
    () async {
      final repository = MockAuthRepository(delay: Duration.zero);
      await repository.signIn('demo@cocenglish.test', 'duolingo-demo');
      final c = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      final sub = c.listen(passwordChangeProvider, (_, _) {});
      addTearDown(() {
        sub.close();
        c.dispose();
      });
      final vm = c.read(passwordChangeProvider.notifier);
      vm.edit(0, 'wrong');
      vm.edit(1, 'replacement-demo');
      vm.edit(2, 'replacement-demo');
      expect(await vm.save(), isFalse);
      final failed = c.read(passwordChangeProvider);
      expect(failed.values, ['wrong', 'replacement-demo', 'replacement-demo']);
      expect(failed.error, isNotNull);
      expect(
        await repository.signIn('demo@cocenglish.test', 'duolingo-demo'),
        isNotNull,
      );
      vm.edit(0, 'duolingo-demo');
      expect(await vm.save(), isTrue);
      expect(c.read(passwordChangeProvider).values, ['', '', '']);
      expect(
        await repository.signIn('demo@cocenglish.test', 'replacement-demo'),
        isNotNull,
      );
      await expectLater(
        repository.signIn('demo@cocenglish.test', 'duolingo-demo'),
        throwsA(isA<AuthFailure>()),
      );
    },
  );
  test(
    'invalid fields never invoke writer and visibility is independent',
    () async {
      var calls = 0;
      final c = ProviderContainer(
        overrides: [
          passwordChangeWriterProvider.overrideWithValue((_, _) async {
            calls++;
          }),
        ],
      );
      final sub = c.listen(passwordChangeProvider, (_, _) {});
      addTearDown(() {
        sub.close();
        c.dispose();
      });
      final vm = c.read(passwordChangeProvider.notifier);
      vm.edit(0, 'duolingo-demo');
      vm.edit(1, 'short');
      vm.edit(2, 'short');
      expect(await vm.save(), isFalse);
      expect(calls, 0);
      vm.edit(1, 'replacement-demo');
      vm.edit(2, 'different-demo');
      expect(await vm.save(), isFalse);
      expect(calls, 0);
      vm.toggleHidden(1);
      expect(c.read(passwordChangeProvider).hidden, [true, false, true]);
    },
  );
  test(
    'busy blocks duplicate submission and dispose prevents stale writes',
    () async {
      final gate = Completer<void>();
      var calls = 0;
      final c = ProviderContainer(
        overrides: [
          passwordChangeWriterProvider.overrideWithValue((_, _) {
            calls++;
            return gate.future;
          }),
        ],
      );
      c.listen(passwordChangeProvider, (_, _) {});
      final vm = c.read(passwordChangeProvider.notifier);
      vm.edit(0, 'duolingo-demo');
      vm.edit(1, 'replacement-demo');
      vm.edit(2, 'replacement-demo');
      final pending = vm.save();
      expect(await vm.save(), isFalse);
      expect(calls, 1);
      vm.edit(1, 'ignored');
      expect(c.read(passwordChangeProvider).values[1], 'replacement-demo');
      c.dispose();
      gate.complete();
      expect(await pending, isFalse);
    },
  );
}

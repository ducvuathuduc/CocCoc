import 'package:cocenglish/main.dart';
import 'package:cocenglish/features/onboarding/data/onboarding_repository.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'storage read failure cannot overwrite saved answers; Retry restores them',
    (tester) async {
      final repository = _LoadFailsOnce();
      await tester.pumpWidget(AppBootstrap(repository: repository));
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t load your choices.'), findsOneWidget);
      expect(find.text('GET STARTED'), findsNothing);
      expect(repository.saves, 0);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('I’M COMMITTED'), findsOneWidget);
      expect(repository.state.goal, 15);
      expect(repository.saves, 0);
    },
  );
}

class _LoadFailsOnce extends MemoryOnboardingRepository {
  _LoadFailsOnce()
    : super(
        OnboardingState(
          step: OnboardingStep.goal,
          language: 'French',
          knowledge: 1,
          reasonIds: {0},
          goal: 15,
        ),
      );
  bool fail = true;
  int saves = 0;
  @override
  Future<OnboardingState> load() async {
    if (fail) {
      fail = false;
      throw StateError('Storage unavailable');
    }
    return super.load();
  }

  @override
  Future<void> save(OnboardingState state) async {
    saves++;
    await super.save(state);
  }
}

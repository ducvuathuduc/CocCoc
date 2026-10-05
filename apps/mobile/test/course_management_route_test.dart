import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/account/application/course_management_controller.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'Settings courses entry opens management and back retains English learning',
    (t) async {
      await t.pumpWidget(
        MainApp(
          initial: OnboardingState(
            step: OnboardingStep.lessonEntry,
            language: 'English',
          ),
        ),
      );
      await t.pumpAndSettle();
      final context = t.element(find.byTooltip('Practice'));
      final c = ProviderScope.containerOf(context);
      final before = c.read(learningStateProvider);
      GoRouter.of(context).push('/settings');
      await t.pumpAndSettle();
      await t.tap(find.text('My courses'));
      await t.pumpAndSettle();
      expect(find.text('Courses'), findsOneWidget);
      expect(c.read(courseManagementProvider).courses.first.name, 'English');
      expect(c.read(learningStateProvider), same(before));
      expect(
        GoRouter.of(t.element(find.text('Courses'))).state.uri.path,
        '/settings/courses',
      );
      GoRouter.of(t.element(find.text('Courses'))).pop();
      await t.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(c.read(learningStateProvider), same(before));
    },
  );
}

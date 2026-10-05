import 'package:cocenglish/features/account/application/course_management_controller.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('English is protected with a visible fixture reason', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(courseManagementProvider.notifier);

    expect(controller.requestRemoval('english'), isFalse);
    expect(
      container.read(courseManagementProvider).protectionMessage,
      'English is your active mock course and cannot be removed.',
    );
    expect(
      container
          .read(courseManagementProvider)
          .courses
          .map((course) => course.id),
      contains('english'),
    );
  });

  test('cancel retains enrollment and confirmation removes once', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(courseManagementProvider.notifier);

    expect(controller.requestRemoval('italian'), isTrue);
    controller.cancelRemoval();
    expect(
      container
          .read(courseManagementProvider)
          .courses
          .map((course) => course.id),
      contains('italian'),
    );

    expect(controller.requestRemoval('italian'), isTrue);
    final removal = controller.confirmRemoval();
    expect(
      container.read(courseManagementProvider).phase,
      CourseRemovalPhase.removing,
    );
    expect(await removal, isTrue);
    expect(
      container
          .read(courseManagementProvider)
          .courses
          .map((course) => course.id),
      isNot(contains('italian')),
    );
    expect(await controller.confirmRemoval(), isFalse);
    expect(controller.requestRemoval('italian'), isFalse);
  });

  test('course removal leaves learning progress state untouched', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final learningBefore = container.read(learningStateProvider);
    final controller = container.read(courseManagementProvider.notifier);

    controller.requestRemoval('chinese');
    await controller.confirmRemoval();

    expect(container.read(learningStateProvider), same(learningBefore));
  });

  test(
    'disposal during removal resolves false without stale state access',
    () async {
      final container = ProviderContainer();
      final controller = container.read(courseManagementProvider.notifier);

      expect(controller.requestRemoval('indonesian'), isTrue);
      final removal = controller.confirmRemoval();
      expect(
        container.read(courseManagementProvider).phase,
        CourseRemovalPhase.removing,
      );
      container.dispose();

      expect(await removal, isFalse);
    },
  );
}

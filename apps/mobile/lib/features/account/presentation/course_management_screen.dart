import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/course_management_controller.dart';

const _cryingDuo = ArtRegion(
  'course-remove',
  Rect.fromLTWH(420, 1660, 340, 350),
);

class CourseManagementScreen extends ConsumerWidget {
  const CourseManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courseManagementProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 49,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text(
                    'Courses',
                    style: TextStyle(
                      color: ReferenceColors.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Positioned(
                    left: 6,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back',
                      icon: const ReferenceBackIcon(),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(
              height: 1,
              thickness: 1,
              color: ReferenceColors.border,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 24, 8, 24),
                child: Column(
                  children: [
                    _CourseList(
                      courses: state.courses,
                      removingId: state.phase == CourseRemovalPhase.removing
                          ? state.pendingCourseId
                          : null,
                      onRemove: (course) =>
                          _requestRemoval(context, ref, course),
                    ),
                    if (state.protectionMessage != null)
                      Semantics(
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                          child: Text(
                            state.protectionMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: ReferenceColors.muted,
                              fontSize: 16,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestRemoval(
    BuildContext context,
    WidgetRef ref,
    ManagedCourse course,
  ) async {
    final controller = ref.read(courseManagementProvider.notifier);
    if (!controller.requestRemoval(course.id)) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ReferenceColors.surface,
      barrierColor: Colors.black38,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RemoveCourseSheet(course: course),
    );
    if (controller.isAlive) controller.cancelRemoval();
  }
}

class _CourseList extends StatelessWidget {
  const _CourseList({
    required this.courses,
    required this.removingId,
    required this.onRemove,
  });

  final List<ManagedCourse> courses;
  final String? removingId;
  final ValueChanged<ManagedCourse> onRemove;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      border: Border.all(color: ReferenceColors.border, width: 2),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      children: [
        for (var index = 0; index < courses.length; index++) ...[
          _CourseRow(
            course: courses[index],
            removing: removingId == courses[index].id,
            onRemove: () => onRemove(courses[index]),
          ),
          if (index != courses.length - 1)
            const Divider(
              height: 2,
              thickness: 2,
              color: ReferenceColors.border,
            ),
        ],
      ],
    ),
  );
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({
    required this.course,
    required this.removing,
    required this.onRemove,
  });

  final ManagedCourse course;
  final bool removing;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 120),
    opacity: removing ? .45 : 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 66),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Semantics(
              label: 'Remove ${course.name} course',
              button: true,
              enabled: !removing,
              child: ExcludeSemantics(
                child: InkResponse(
                  onTap: removing ? null : onRemove,
                  radius: 24,
                  child: const SizedBox(
                    width: 38,
                    height: 38,
                    child: Center(child: _RemoveIcon()),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _CourseFlag(course.id),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                course.name,
                style: const TextStyle(
                  color: ReferenceColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RemoveIcon extends StatelessWidget {
  const _RemoveIcon();

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: const BoxDecoration(
      color: Color(0xFFFF4B4B),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Container(
      width: 10,
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}

class _CourseFlag extends StatelessWidget {
  const _CourseFlag(this.courseId);

  final String courseId;

  @override
  Widget build(BuildContext context) {
    if (courseId == 'english') {
      return const ReferenceArt(LearningArt.english, width: 46, height: 36);
    }
    if (courseId == 'chinese') {
      return const SizedBox(
        width: 46,
        height: 36,
        child: FittedBox(child: ChineseFlag()),
      );
    }
    final colors = switch (courseId) {
      'english' => const [Color(0xFF1CB0F6), Colors.white, Color(0xFFFF4B4B)],
      'indonesian' => const [Color(0xFFFF4B4B), Color(0xFFF3F3F3)],
      _ => const [Color(0xFF58CC02), Colors.white, Color(0xFFFF4B4B)],
    };
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: SizedBox(
          width: 46,
          height: 36,
          child: courseId == 'indonesian'
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final color in colors)
                      Expanded(child: ColoredBox(color: color)),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final color in colors)
                      Expanded(child: ColoredBox(color: color)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _RemoveCourseSheet extends ConsumerWidget {
  const _RemoveCourseSheet({required this.course});

  final ManagedCourse course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courseManagementProvider);
    final removing = state.phase == CourseRemovalPhase.removing;
    return Semantics(
      label: 'Remove ${course.name} course confirmation',
      namesRoute: true,
      child: FractionallySizedBox(
        heightFactor: .62,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    constraints.maxHeight -
                    28 -
                    MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: ReferenceColors.disabled,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Are you sure?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ReferenceColors.ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        child: Text(
                          'Be careful, deleting a course gets rid of all your '
                          'progress and cannot be undone.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ReferenceColors.muted,
                            fontSize: 20,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const ReferenceArt(_cryingDuo, width: 112, height: 115),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Column(
                      children: [
                        ReferenceButton(
                          label: removing ? 'REMOVING…' : 'REMOVE',
                          backgroundColor: const Color(0xFFFF4B4B),
                          edgeColor: const Color(0xFFD33131),
                          onPressed: removing
                              ? null
                              : () async {
                                  final removal = ref
                                      .read(courseManagementProvider.notifier)
                                      .confirmRemoval();
                                  Navigator.of(context).pop();
                                  await removal;
                                },
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: removing
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text(
                            'CANCEL',
                            style: TextStyle(
                              color: ReferenceColors.blue,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

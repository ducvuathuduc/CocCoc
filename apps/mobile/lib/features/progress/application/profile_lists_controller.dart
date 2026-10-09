import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/application/course_management_controller.dart';
import '../../learning/application/learning_controller.dart';
import 'preview_controller.dart';
import 'profile_surface_controller.dart';

class ProfileCourse {
  const ProfileCourse(this.id, this.name, this.xp);
  final String id, name;
  final int xp;
}

// Read-only projections of the authorized local fixtures. Listing or opening a
// profile never selects a course or changes a learning reward.
final profileCoursesProvider = Provider<List<ProfileCourse>>((ref) {
  final enrolled = ref.watch(courseManagementProvider.select((s) => s.courses));
  final xp = ref.watch(learningStateProvider.select((s) => s.xp));
  return List.unmodifiable([
    for (final course in enrolled)
      ProfileCourse(course.id, course.name, course.id == 'english' ? xp : 0),
  ]);
});

enum ProfileFriendsTab { following, followers }

final profileFollowingProvider = Provider<List<String>>((ref) {
  final names = ref.watch(previewControllerProvider.select((s) => s.following));
  return List.unmodifiable(names.toList()..sort());
});

final profileFollowersProvider = Provider<List<String>>((ref) {
  final names = ref.watch(profileSurfaceProvider.select((s) => s.followers));
  return List.unmodifiable(names);
});
